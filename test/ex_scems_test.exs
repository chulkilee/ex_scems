defmodule ExSCEMSTest do
  use ExUnit.Case, async: true
  doctest ExSCEMS

  alias ExSCEMS.{Config, Response}

  @session_id "FAKE_SESSION_ID"

  setup do
    bypass = Bypass.open()

    config = %Config{
      endpoint: "http://127.0.0.1:#{bypass.port}",
      session_id: @session_id
    }

    {:ok, bypass: bypass, config: config}
  end

  #
  # Authentication
  #

  test "login_by_vendor - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/verifyLogin.xml", fn conn ->
      conn
      |> assert_request_body(%{"userName" => "foo", "password" => "bar"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
           <sessionId>F53FD7E013F8358C936851EF5D6835CD</sessionId>
           <stat>ok</stat>
         </emsResponse>
         """)
    end)

    {:ok, %Response{stat: "ok"}, "F53FD7E013F8358C936851EF5D6835CD"} =
      ExSCEMS.login_by_vendor("http://127.0.0.1:#{bypass.port}", "foo", "bar")
  end

  test "login_by_vendor - fail", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/verifyLogin.xml", fn conn ->
      conn
      |> assert_request_body(%{"userName" => "foo", "password" => "bar"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
          <code>215</code>
          <desc>Incorrect user name or password provided.</desc>
          <stat>fail</stat>
         </emsResponse>
         """)
    end)

    {:error, %Response{
      error_code: "215",
      error_desc: "Incorrect user name or password provided.",
      stat: "fail"
    }} = ExSCEMS.login_by_vendor("http://127.0.0.1:#{bypass.port}", "foo", "bar")
  end

  #
  # Util
  #

  defp assert_request_body(conn, expected) do
    conn2 = Plug.Parsers.call(conn, Plug.Parsers.init(parsers: [:urlencoded]))
    assert expected == conn2.body_params
    conn
  end
end
