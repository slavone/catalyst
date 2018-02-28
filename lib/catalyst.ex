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
      {:ok, 200, "content"}
  """
  def get(uri) do
    config = get_state()
    status = get config.host, uri, config.digest
  end

  @doc """
  PUT data into a resource at specified URI

  ## Examples
      iex> Catalyst.put "/some_resource.txt", "content"
      {:ok, 201, "content"}
  """
  def put(uri, data) do
    config = get_state()
    put config.host, uri, data, config.digest
  end

  @doc """
  MOVE data from source uri to destination uri

  ## Examples
      iex> Catalyst.move "/some_dir/some_resource.txt", "/some_resource.txt"
      {:ok, 204, ""}
  """
  def move(source_uri, destination_uri) do
    config = get_state()
    move config.host, source_uri, destination_uri, config.digest
  end

  @doc """
  DELETE resource at specified URI

  ## Examples
      iex> Catalyst.delete "/some_resource.txt"
      {:ok, 204, ""}
  """
  def delete(uri) do
    config = get_state()
    delete config.host, uri, config.digest
  end

  @doc """
  Creates directory at specified URI

  ## Examples
      iex> Catalyst.mkcol "/new_dir/"
      {:ok, 201, ""}
  """
  def mkcol(uri) do
    config = get_state()
    mkcol config.host, uri, config.digest
  end

  @doc """
  Creates directories recursirve at specified URI

  ## Examples 
      iex> Catalyst.mkcol "/new_dir/level_2/level_3/"
      {:ok, 201, ""}
  """
  def mkcol_p(uri) do
    uri
    |> String.split("/", trim: true)
    |> Enum.reduce("/", fn dir, path ->
      path = "#{path}#{dir}/"
      {:ok, 201, _} = mkcol(path)
      path
    end)

    {:ok, 201, ""}
  end

  @doc """
  HEAD request at specified URI

  ## Examples
      iex> Catalyst.head "/new_dir/"
      {:ok, 200, ""}
  """
  def head(uri) do
    config = get_state()
    head config.host, uri, config.digest
  end

  @doc """
  Upload file contents at specified URI

  ## Examples
      iex> Catalyst.put_file "/some_dir/new_file.txt", "files/some_file.txt"
      {:ok, 201, ""}
  """
  def put_file(uri, filepath) do
    config = get_state()
    put_file config.host, uri, filepath, config.digest
  end

  @doc """
  Recursively uploads whole directory to specified webdav dir

  ## Examples
      iex> Catalyst.put_directory "/some_dir/", "files"
      :ok
  """
  def put_directory(uri, dir_path) do
    config = get_state()
    put_directory config.host, uri, dir_path, config.digest
  end

  @doc """
  Starts the webdav client genserver

  ## Examples
      iex> Catalyst.start_link host: "http://webdav.server", user: "some_user", password: "password"
      {:ok, #PID<0.175.0>}
  """
  def start_link(credentials) do
    state = init_state credentials
    Agent.start_link fn -> state end, name: __MODULE__
  end

  # Lower level API

  def head(host, uri, digest) do
    # Http.http_request :head, full_url(host, uri), [auth_header(digest)]
    {:ok, status, _, body} = :hackney.head(full_url(host, uri), [auth_header(digest)], "", with_body: true)
    {:ok, status, body}
  end

  def get(host, uri, digest) do
    {:ok, status, _, body} = :hackney.get(full_url(host, uri), [auth_header(digest)], "", with_body: true)
    {:ok, status, body}
  end

  def put(host, uri, {:file, _} = data, digest) do
    headers = [auth_header(digest)]
    {:ok, pid} = :hackney.request(:put, full_url(host, uri), headers, :stream_multipart, [])
    :hackney.send_multipart_body(pid, data)
    {:ok, status, _, pid} = :hackney.start_response(pid)
    {:ok, body} = :hackney.body(pid)
    {:ok, status, body}
  end
  def put(host, uri, data, digest) do
    {:ok, pid} = :hackney.request(:put, full_url(host, uri), [auth_header(digest)], :stream, [])
    :hackney.send_body(pid, data)
    {:ok, status, _, pid} = :hackney.start_response(pid)
    {:ok, body} = :hackney.body(pid)
    {:ok, status, body}
  end

  def put_file(host, uri, filepath, digest) do
    case File.stat(filepath) do
      {:ok, %{type: :regular}} -> put host, uri, {:file, filepath}, digest
      {:ok, %{type: :directory}} -> raise "#{filepath} is a directory, use :put_directory"
      {:error, _} -> raise "Could not open file at #{filepath}"
    end
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

  def move(host, source_uri, destination_uri, digest) do
    dest_header = {"Destination", destination_uri}
    {:ok, status, _, body} = :hackney.move(full_url(host, source_uri), [auth_header(digest), dest_header], "", with_body: true)
    {:ok, status, body}
  end

  def mkcol(host, uri, digest) do
    {:ok, status, _, body} = :hackney.mkcol(full_url(host, uri), [auth_header(digest)], "", with_body: true)
    {:ok, status, body}
  end

  def delete(host, uri, digest) do
    {:ok, status, _, body} = :hackney.delete(full_url(host, uri), [auth_header(digest)], "", with_body: true)
    {:ok, status, body}
  end

  # Helper methods

  defp init_state(config) do
    conf = Enum.into config, %{}
    if conf[:digest] do
      %Credentials{host: conf.host, digest: conf.digest}
    else
      digest = auth_digest(conf.user, conf.password)
      %Credentials{host: conf.host, digest: digest}
    end
  end

  defp get_state, do: Agent.get __MODULE__, &(&1)

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
