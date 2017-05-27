defmodule CatalystTest do
  use ExUnit.Case

  setup_all do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Exdav, [base_file_path: Path.absname("test"), user: "abc", password: "123"], port: 1337)
    ]

    Catalyst.start_link host: "http://localhost:1337", user: "abc", password: "123"
    Supervisor.start_link(children, strategy: :one_for_one)
    :ok
  end

  test "GET" do
    resp_before = Catalyst.get "/file.txt"
    assert resp_before == {{'HTTP/1.1', 404, 'Not Found'}, []}
    File.open("test/file.txt", [:write], fn(file) ->
        IO.binwrite(file, "abcd")
    end)
    resp_after = Catalyst.get "/file.txt"
    assert resp_after == {{'HTTP/1.1', 200, 'OK'}, 'abcd'}
    File.rm "test/file.txt"
  end

  test "PUT" do
    resp = Catalyst.put "/new_dir/file.txt", "data"
    assert resp == {{'HTTP/1.1', 201, 'Created'}, []}
    assert File.read("test/new_dir/file.txt") == {:ok, "data"}
    File.rm "test/new_dir/file.txt"
  end

end
