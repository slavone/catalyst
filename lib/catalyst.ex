defmodule Catalyst do
  use GenServer

  alias Catalyst.Http

  @moduledoc """
  Basic webdav client, build around genserver
  """

  defmodule Credentials do
    @moduledoc """
    Stores wedbav server hostname and authentication digest
    """
    defstruct host: nil, digest: nil
  end

  # Public API

  @doc """
  Makes a GET request to a resource at specified URI

  ## Examples
      iex> Catalyst.get "/some_resource.txt"
      {{'HTTP/1.1', 200, 'Ok'}, 'content'}
  """
  def get(uri) do
    GenServer.call __MODULE__, {:get, uri}
  end

  @doc """
  PUT data into a resource at specified URI

  ## Examples
      iex> Catalyst.put "/some_resource.txt", "content"
      {{'HTTP/1.1', 201, 'Created'}, []}
  """
  def put(uri, data) do
    GenServer.call __MODULE__, {:put, uri, data}
  end

  @doc """
  DELETE resource at specified URI

  ## Examples
      iex> Catalyst.delete "/some_resource.txt"
      {{'HTTP/1.1', 204, 'No Content'}, []}
  """
  def delete(uri) do
    GenServer.call __MODULE__, {:delete, uri}
  end

  @doc """
  Creates directory at specified URI

  DISCLAIMER: erlang :httpc does not support MKCOL method, so this is implemented
  via PUTting tmp_file into the new directory and then deleting the file,
  leaving an empty new dir

  ## Examples
      iex> Catalyst.mkcol "/new_dir/"
      {{'HTTP/1.1', 204, 'No Content'}, []}
  """
  def mkcol(uri) do
    GenServer.call __MODULE__, {:mkcol, uri}
  end

  @doc """
  HEAD request at specified URI

  ## Examples
      iex> Catalyst.head "/new_dir/"
      {{'HTTP/1.1', 200, 'OK'}, []}
  """
  def head(uri) do
    GenServer.call __MODULE__, {:head, uri}
  end

  @doc """
  Upload file contents at specified URI

  ## Examples
      iex> Catalyst.put_file "/some_dir/new_file.txt", "files/some_file.txt"
      {{'HTTP/1.1', 201, 'OK'}, []}
  """
  def put_file(uri, filepath) do
    GenServer.call __MODULE__, {:put_file, uri, filepath}
  end

  @doc """
  Recursively uploads whole directory to specified webdav dir

  ## Examples
      iex> Catalyst.put_directory "/some_dir/", "files"
      :ok
  """
  def put_directory(uri, dir_path) do
    GenServer.call __MODULE__, {:put_directory, uri, dir_path}
  end

  @doc """
  Starts the webdav client genserver

  ## Examples
      iex> Catalyst.start_link host: "http://webdav.server", user: "some_user", password: "password"
      {:ok, #PID<0.175.0>}
  """
  def start_link(credentials) do
    GenServer.start_link(__MODULE__, credentials, name: __MODULE__)
  end

  # Lower level API

  def head(host, uri, digest) do
    Http.http_request :head, full_url(host, uri), [auth_header(digest)]
  end

  def get(host, uri, digest) do
    Http.http_request :get , full_url(host, uri), [auth_header(digest)]
  end

  def put(host, uri, data, digest) do
    Http.http_request :put, full_url(host, uri), [auth_header(digest)],
      'multipart/form-data', data
  end

  def put_file(host, uri, filepath, digest) do
    data = case File.read(filepath) do
      {:ok, data} -> data
      {:error, _} -> raise "Could not open file at #{filepath}"
    end
    put host, uri, data, digest
  end

  def put_directory(host, uri, dir_path, digest) do
    if !File.dir?(dir_path) do
      raise "File #{dir_path} is not directory or does not exist."
    end
    base_dir = Path.basename dir_path
    put_directory host, uri, dir_path, base_dir, digest
    :ok
  end
  defp put_directory(host, uri, dir_path, base_dir, digest) do
    if File.dir?(dir_path) do
      Enum.each(Path.wildcard("#{dir_path}/*"), fn(file) ->
        put_directory host, uri, file, base_dir, digest
      end)
    else
      file_path = "#{uri}/#{relative_path(dir_path, base_dir)}"
      put_file(host, file_path, dir_path, digest)
    end
  end

  # erlang httpc library doesnt support MOVE method
  # so heres a workaround that gets the same effect
  def move(host, source_uri, destination_uri, digest) do
    {{_, 200, _}, body} = get(host, source_uri, digest)
    put(host, destination_uri, body, digest)
    delete(host, source_uri, digest)
  end

  # erlang httpc library doesnt support MKCOL method
  # so heres a workaround that gets the same effect
  def mkcol(host, uri, digest) do
    tmp_uri = "#{uri}/tmp_file"
    result = put host, tmp_uri, "", digest
    delete(host, tmp_uri, digest)
    result
  end

  # GenServer callbacks

  def init(config) do
    conf = Enum.into config, %{}
    state = if conf[:digest] do
      %Credentials{host: conf.host, digest: conf.digest}
    else
      digest = auth_digest(conf.user, conf.password)
      %Credentials{host: conf.host, digest: digest}
    end
    {:ok, state}
  end

  def handle_call({:head, uri}, _from, config) do
    status = head config.host, uri, config.digest
    {:reply, status, config}
  end

  def handle_call({:get, uri}, _from, config) do
    status = get config.host, uri, config.digest
    {:reply, status, config}
  end

  def handle_call({:put, uri, data}, _from, config) do
    status = put config.host, uri, data, config.digest
    {:reply, status, config}
  end

  def handle_call({:put_file, uri, filepath}, _from, config) do
    status = put_file config.host, uri, filepath, config.digest
    {:reply, status, config}
  end

  def handle_call({:put_directory, uri, dir_path}, _from, config) do
    put_directory config.host, uri, dir_path, config.digest
    {:reply, :ok, config}
  end

  def handle_call({:mkcol, uri}, _from, config) do
    status = mkcol config.host, uri, config.digest
    {:reply, status, config}
  end

  def handle_call({:move, source_uri, dest_uri}, _from, config) do
    status = move config.host, source_uri, dest_uri, config.digest
    {:reply, status, config}
  end

  def handle_call({:delete, uri}, _from, config) do
    status = delete config.host, uri, config.digest
    {:reply, status, config}
  end

  def delete(host, uri, digest) do
    Http.http_request :delete, full_url(host, uri), [auth_header(digest)]
  end

  # Helper methods

  defp auth_header(digest), do: {'Authorization', 'Basic ' ++ digest}
  defp full_url(host, uri), do: to_charlist(host <> uri)

  defp relative_path(dir_path, base_dir) do
    [root | tail] = String.split(dir_path, base_dir, parts: 2)
    if root != "" do
      base_dir <> List.first(tail)
    else
      dir_path
    end
  end

  defp auth_digest(user, password) do
    "#{user}:#{password}"
      |> to_charlist()
      |> :base64.encode_to_string()
  end
end
