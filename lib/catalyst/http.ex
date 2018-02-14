defmodule Catalyst.Http do
  @moduledoc """
  Wrappers around erlangs :httpc for conveniences
  """

  @doc """
  Makes an http requst, allows to pass headers

  ## Examples
    iex> Catalyst.Http.http_request :get, 'http://example.com'
    {{'HTTP/1.1', 200, 'Ok'}, 'body'}
  """
  def http_request(method, url, headers \\ []) do
    handle_response :httpc.request(method, request_load(url, headers), [], [{:body_format, :binary}])
  end
  @doc """
  Makes an http requst, allows to pass headers, content_type and body

  ## Examples
    iex> Catalyst.Http.http_request :put, 'http://webdav.com/some_file.txt', [{'Authorization', 'Basic asdJasd='}], 'multipart/form-data.txt', ""
    {{'HTTP/1.1', 201, 'Created'}, []}
  """
  def http_request(method, url, headers, content_type, body) do
    request_load = request_load(url, headers, content_type, body)

    handle_response :httpc.request(method, request_load, [], [{:body_format, :binary}])
  end

  defp request_load(url, headers \\ []) do
    {url, [] ++ headers}
  end
  defp request_load(url, headers, content_type, body) do
    base = request_load(url, headers)
    base
      |> Tuple.append(content_type)
      |> Tuple.append(body)
  end
  defp handle_response(response) do
    case response do
      {:ok, {status_line, _headers, body}} -> {status_line, body}
      {:error, error} -> error
    end
  end
end
