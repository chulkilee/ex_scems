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

  test "login_by_eid - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/loginByEID.xml", fn conn ->
      conn
      |> assert_request_body(%{"eid" => "c84dc253-a1cf-4eb2-82ae-76cef4cac953"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
          <entId>1234</entId>
          <sessionId>5C579FCFF85D34CBB9D9926DA6635659</sessionId>
          <stat>ok</stat>
         </emsResponse>
         """)
    end)

    {:ok, %Response{stat: "ok"}, "5C579FCFF85D34CBB9D9926DA6635659"} =
      ExSCEMS.login_by_eid(
        "http://127.0.0.1:#{bypass.port}",
        "c84dc253-a1cf-4eb2-82ae-76cef4cac953"
      )
  end

  test "login_by_eid - fail", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/loginByEID.xml", fn conn ->
      conn
      |> assert_request_body(%{"eid" => "c84dc253-a1cf-4eb2-82ae-76cef4cac953"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
          <code>621</code>
          <desc>The entitlement does not exist. Retry with a correct ID.</desc>
          <stat>fail</stat>
         </emsResponse>
         """)
    end)

    {:error, %Response{
      error_code: "621",
      error_desc: "The entitlement does not exist. Retry with a correct ID.",
      stat: "fail"
    }} =
      ExSCEMS.login_by_eid(
        "http://127.0.0.1:#{bypass.port}",
        "c84dc253-a1cf-4eb2-82ae-76cef4cac953"
      )
  end

  test "login_by_contact - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/loginByContact.xml", fn conn ->
      conn
      |> assert_request_body(%{"emailId" => "foo@example.com", "password" => "bar"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
           <entIds>
             <entId>1234</entId>
           </entIds>
           <sessionId>C3ED80479F180EF00F5FB4AEA023E480</sessionId>
           <stat>ok</stat>
         </emsResponse>
         """)
    end)

    {:ok, %Response{stat: "ok"}, "C3ED80479F180EF00F5FB4AEA023E480"} =
      ExSCEMS.login_by_contact("http://127.0.0.1:#{bypass.port}", "foo@example.com", "bar")
  end

  test "login_by_contact - fail", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/loginByContact.xml", fn conn ->
      conn
      |> assert_request_body(%{"emailId" => "foo@example.com", "password" => "bar"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
          <code>217</code>
          <desc>E-mail or password is incorrect. Try again with correct credentials.</desc>
          <stat>fail</stat>
         </emsResponse>
         """)
    end)

    {:error, %Response{
      error_code: "217",
      error_desc: "E-mail or password is incorrect. Try again with correct credentials.",
      stat: "fail"
    }} = ExSCEMS.login_by_contact("http://127.0.0.1:#{bypass.port}", "foo@example.com", "bar")
  end

  #
  # Customer
  #

  test "create_customer - success", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "POST", "/createCustomer.xml", fn conn ->
      conn
      |> assert_request_body(%{
           "customerName" => "foo",
           "customerRefIdType" => "guid",
           "isEnabled" => "true"
         })
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
           <customerId>3682</customerId>
           <stat>ok</stat>
         </emsResponse>
         """)
    end)

    {:ok, %Response{stat: "ok"}, 3682} =
      ExSCEMS.create_customer(
        [customerName: "foo", isEnabled: true, customerRefIdType: "guid"],
        config
      )
  end

  test "create_customer - fail", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "POST", "/createCustomer.xml", fn conn ->
      conn
      |> assert_request_body(%{})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(401, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
           <code>100</code>
           <desc>The request parameter is not valid.</desc>
           <stat>fail</stat>
         </emsResponse>
         """)
    end)

    {:error, %Response{
      error_code: "100",
      error_desc: "The request parameter is not valid.",
      stat: "fail"
    }} = ExSCEMS.create_customer([], config)
  end

  test "delete_customer - success", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "POST", "/deleteCustomerById.xml", fn conn ->
      conn
      |> assert_request_body(%{"customerId" => "1"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
           <customerId>3682</customerId>
           <stat>ok</stat>
         </emsResponse>
         """)
    end)

    {:ok, %{stat: "ok"}} = ExSCEMS.delete_customer(1, config)
  end

  test "delete_customer - fail", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "POST", "/deleteCustomerById.xml", fn conn ->
      conn
      |> assert_request_body(%{"customerId" => "1"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
         <?xml version="1.0" encoding="UTF-8"?>
         <emsResponse>
           <code>519</code>
           <desc>Customer not found for the given customerID.</desc>
           <stat>fail</stat>
         </emsResponse>
         """)
    end)

    {:error, %Response{
      error_code: "519",
      error_desc: "Customer not found for the given customerID.",
      stat: "fail"
    }} = ExSCEMS.delete_customer(1, config)
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
