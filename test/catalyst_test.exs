defmodule CatalystTest do
  use ExUnit.Case

  setup_all do
    exdav_params = [base_file_path: Path.absname("test"), user: "abc", password: "123"]
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Exdav, exdav_params, port: 1337)
    ]

    Application.put_env :catalyst, :config, [host: "http://localhost:1337", user: "abc", password: "123"]
    Supervisor.start_link(children, strategy: :one_for_one)
    :ok
  end

  # test "GET file" do
  #   File.rm "test/file.txt"
  #   resp_before = Catalyst.get "/file.txt"
  #   assert resp_before == {{'HTTP/1.1', 404, 'Not Found'}, []}
  #   File.open("test/file.txt", [:write], fn(file) ->
  #       IO.binwrite(file, "abcd")
  #   end)
  #   resp_after = Catalyst.get "/file.txt"
  #   assert resp_after == {{'HTTP/1.1', 200, 'OK'}, 'abcd'}
  #   File.rm "test/file.txt"
  # end

  test "GET file" do
    File.rm "test/file.txt"
    resp_before = Catalyst.get "/file.txt"
    assert resp_before == {:ok, 404, ""}
    File.open("test/file.txt", [:write], fn(file) ->
        IO.binwrite(file, "abcd")
    end)
    resp_after = Catalyst.get "/file.txt"
    assert resp_after == {:ok, 200, "abcd"}
    File.rm "test/file.txt"
  end

  test "GET directory" do
    File.rmdir "test/dir"
    resp_before = Catalyst.get "/dir"
    assert resp_before == {:ok, 404, ""}
    File.mkdir! "test/dir"
    resp_after = Catalyst.get "/dir"
    assert resp_after == {:ok, 200, ""}
    File.rmdir "test/dir"
  end

  test "PUT data" do
    File.rm "test/file.txt"
    resp = Catalyst.put "/file.txt", "data"
    assert resp == {:ok, 201, ""}
    assert File.read("test/file.txt") == {:ok, "data"}
    File.rm "test/file.txt"
  end

  test "PUT file" do
    File.rm "test/file.txt"
    File.open("test/file.txt", [:write], fn(file) ->
        IO.binwrite(file, "abcd")
    end)
    resp = Catalyst.put_file "/file.txt", "test/file.txt"
    assert resp == {:ok, 201, ""}
    # assert File.read("test/file.txt") == {:ok, "abcd"}
    File.rm "test/file.txt"
  end

  test "MKCOL /dir" do
    File.rmdir "test/dir"
    resp_before = Catalyst.get "/dir"
    assert resp_before == {:ok, 404, ""}
    resp = Catalyst.mkcol "/dir/"
    assert resp == {:ok, 200, ""}
    resp_after = Catalyst.get "/dir"
    assert resp_after == {:ok, 200, ""}
    assert File.dir? "test/dir"
    File.rmdir "test/dir"
  end

  test "DELETE file" do
    resp = Catalyst.delete "/file.txt"
    assert resp == {:ok, 404, ""}
    File.open("test/file.txt", [:write], fn(file) ->
        IO.binwrite(file, "abcd")
    end)
    resp = Catalyst.delete "/file.txt"
    assert resp == {:ok, 200, ""}
    assert File.exists?("test/file.txt") == false
  end
end
