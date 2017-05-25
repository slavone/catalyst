defmodule Catalyst.Http do
  defp handle_response(response) do
    case response do
      {:ok, {status_line, _headers, body}} -> {status_line, body}
      {:error, error} -> error
    end
  end

  def http_request(method, url, headers \\ []) do
    handle_response :httpc.request(method, request_load(url, headers), [], [])
  end
  def http_request(method, url, headers, content_type, body) do
    request_load = request_load(url, headers, content_type, body)

    handle_response :httpc.request(method, request_load, [], [])
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
end
