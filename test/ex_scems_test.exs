defmodule ExSCEMSTest do
  use ExUnit.Case, async: true
  doctest ExSCEMS

  alias ExSCEMS.Response
  alias ExSCEMS.{Contact, Customer, Entitlement, LineItem, Product}

  @session_id "FAKE_SESSION_ID"

  setup do
    bypass = Bypass.open()

    client = ExSCEMS.build_client("http://127.0.0.1:#{bypass.port}", @session_id)

    {:ok, bypass: bypass, client: client}
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

    {:error,
     %Response{
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

    {:error,
     %Response{
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

    {:error,
     %Response{
       error_code: "217",
       error_desc: "E-mail or password is incorrect. Try again with correct credentials.",
       stat: "fail"
     }} = ExSCEMS.login_by_contact("http://127.0.0.1:#{bypass.port}", "foo@example.com", "bar")
  end

  #
  # Customer
  #

  test "create_customer - success", %{bypass: bypass, client: client} do
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
        client,
        customerName: "foo",
        isEnabled: true,
        customerRefIdType: "guid"
      )
  end

  test "create_customer - fail", %{bypass: bypass, client: client} do
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

    {:error,
     %Response{
       error_code: "100",
       error_desc: "The request parameter is not valid.",
       stat: "fail"
     }} = ExSCEMS.create_customer(client, [])
  end

  test "delete_customer - success", %{bypass: bypass, client: client} do
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

    {:ok, %{stat: "ok"}} = ExSCEMS.delete_customer(client, 1)
  end

  test "delete_customer - fail", %{bypass: bypass, client: client} do
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

    {:error,
     %Response{
       error_code: "519",
       error_desc: "Customer not found for the given customerID.",
       stat: "fail"
     }} = ExSCEMS.delete_customer(client, 1)
  end

  test "search_customers - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/searchCustomers.xml", fn conn ->
      conn
      |> assert_query(%{"pageSize" => "1"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <customers>
          <customer>
            <creationTime>1483228800000</creationTime>
            <customerId>123</customerId>
            <customerName>dummy-customer-name</customerName>
            <customerRefId>dummy-customer-ref-id</customerRefId>
            <desc>dummy-desc</desc>
            <enabled>true</enabled>
            <modificationTime>1514764799000</modificationTime>
            <refId>dummy-ref-id</refId>
            <timezone>(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London</timezone>
          </customer>
        </customers>
        <stat>ok</stat>
        <total>2</total>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, customers} = ExSCEMS.search_customers(client, pageSize: 1)

    expected = %Customer{
      contacts: nil,
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      id: 123,
      name: "dummy-customer-name",
      customer_ref_id: "dummy-customer-ref-id",
      description: "dummy-desc",
      enabled: true,
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      ref_id: "dummy-ref-id",
      timezone: "(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London"
    }

    assert [expected] == customers
  end

  test "search_customers_by_name - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/getCustomerByCustomerName.xml", fn conn ->
      conn
      |> assert_query(%{"customerName" => "foo"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <customers>
          <customer>
            <contacts>
              <contact>
                <admin>false</admin>
                <contactEmail>contact@example.com</contactEmail>
                <contactId>129</contactId>
                <contactName>TestContact</contactName>
                <creationTime>1483228800000</creationTime>
                <customerName>TestCustomer</customerName>
                <modificationTime>1514764799000</modificationTime>
                <status>false</status>
              </contact>
            </contacts>
            <creationTime>1483228800000</creationTime>
            <customerId>123</customerId>
            <customerName>dummy-customer-name</customerName>
            <customerRefId>dummy-customer-ref-id</customerRefId>
            <desc>dummy-desc</desc>
            <enabled>true</enabled>
            <modificationTime>1514764799000</modificationTime>
            <refId>dummy-ref-id</refId>
            <timezone>(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London</timezone>
          </customer>
        </customers>
        <stat>ok</stat>
        <total>1</total>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, customers} = ExSCEMS.search_customers_by_name(client, "foo")

    expected = %Customer{
      contacts: [
        %Contact{
          email: "contact@example.com",
          id: 129,
          name: "TestContact",
          creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
          modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z")
        }
      ],
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      id: 123,
      name: "dummy-customer-name",
      customer_ref_id: "dummy-customer-ref-id",
      description: "dummy-desc",
      enabled: true,
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      ref_id: "dummy-ref-id",
      timezone: "(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London"
    }

    assert [expected] == customers
  end

  test "get_customer_by_id - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/getCustomerById.xml", fn conn ->
      conn
      |> assert_query(%{"customerId" => "123"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <customer>
          <contacts>
            <contact>
              <admin>false</admin>
              <contactEmail>contact@example.com</contactEmail>
              <contactId>129</contactId>
              <contactName>TestContact</contactName>
              <creationTime>1483228800000</creationTime>
              <customerName>TestCustomer</customerName>
              <modificationTime>1514764799000</modificationTime>
              <status>false</status>
            </contact>
          </contacts>
          <creationTime>1483228800000</creationTime>
          <customerId>123</customerId>
          <customerName>dummy-customer-name</customerName>
          <customerRefId>dummy-customer-ref-id</customerRefId>
          <desc>dummy-desc</desc>
          <enabled>true</enabled>
          <modificationTime>1514764799000</modificationTime>
          <refId>dummy-ref-id</refId>
          <timezone>(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London</timezone>
        </customer>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, customer} = ExSCEMS.get_customer_by_id(client, 123)

    expected = %Customer{
      contacts: [
        %Contact{
          email: "contact@example.com",
          id: 129,
          name: "TestContact",
          creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
          modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z")
        }
      ],
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      id: 123,
      name: "dummy-customer-name",
      customer_ref_id: "dummy-customer-ref-id",
      description: "dummy-desc",
      enabled: true,
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      ref_id: "dummy-ref-id",
      timezone: "(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London"
    }

    assert expected == customer
  end

  test "get_customer_by_customer_ref_id - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/getCustomerByCustomerRefId.xml", fn conn ->
      conn
      |> assert_query(%{"customerRefId" => "dummy-customer-ref-id"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <customer>
          <contacts>
            <contact>
              <admin>false</admin>
              <contactEmail>contact@example.com</contactEmail>
              <contactId>129</contactId>
              <contactName>TestContact</contactName>
              <creationTime>1483228800000</creationTime>
              <customerName>TestCustomer</customerName>
              <modificationTime>1514764799000</modificationTime>
              <status>false</status>
            </contact>
          </contacts>
          <creationTime>1483228800000</creationTime>
          <customerId>123</customerId>
          <customerName>dummy-customer-name</customerName>
          <customerRefId>dummy-customer-ref-id</customerRefId>
          <desc>dummy-desc</desc>
          <enabled>true</enabled>
          <modificationTime>1514764799000</modificationTime>
          <refId>dummy-ref-id</refId>
          <timezone>(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London</timezone>
        </customer>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, customer} =
      ExSCEMS.get_customer_by_customer_ref_id(client, "dummy-customer-ref-id")

    expected = %Customer{
      contacts: [
        %Contact{
          email: "contact@example.com",
          id: 129,
          name: "TestContact",
          creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
          modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z")
        }
      ],
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      id: 123,
      name: "dummy-customer-name",
      customer_ref_id: "dummy-customer-ref-id",
      description: "dummy-desc",
      enabled: true,
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      ref_id: "dummy-ref-id",
      timezone: "(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London"
    }

    assert expected == customer
  end

  #
  # Product
  #

  test "create_product - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/createProduct.xml", fn conn ->
      conn
      |> assert_request_body(%{
        "namespaceName" => "Default",
        "productName" => "FooProduct",
        "productVersion" => "2",
        "productDescription" => "description",
        "serviceAgreementID" => "2"
      })
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <productId>1</productId>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %Response{stat: "ok"}, 1} =
      ExSCEMS.create_product(
        client,
        namespaceName: "Default",
        productName: "FooProduct",
        productVersion: "2",
        productDescription: "description",
        serviceAgreementID: 2
      )
  end

  test "create_product - fail", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/createProduct.xml", fn conn ->
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

    {:error,
     %Response{
       error_code: "100",
       error_desc: "The request parameter is not valid.",
       stat: "fail"
     }} = ExSCEMS.create_product(client, [])
  end

  test "search_products - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/searchProducts.xml", fn conn ->
      conn
      |> assert_query(%{"pageSize" => "1"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <products>
          <product>
            <creationTime>1483228800000</creationTime>
            <deployed>true</deployed>
            <id>18</id>
            <lifeCycleStage>Complete</lifeCycleStage>
            <modificationTime>1514764799000</modificationTime>
            <name>TestProduct</name>
            <namespaceId>2</namespaceId>
            <namespaceName>TestNamespace</namespaceName>
            <refId1>ref-id-1</refId1>
            <refId2>ref-id-2</refId2>
            <saId>1</saId>
            <ver>23</ver>
          </product>
        </products>
        <stat>ok</stat>
        <total>3</total>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, products} = ExSCEMS.search_products(client, pageSize: 1)

    expected = %Product{
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      deployed: true,
      description: nil,
      id: 18,
      life_cycle_stage: "Complete",
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      name: "TestProduct",
      namespace_id: 2,
      namespace_name: "TestNamespace",
      ref_id1: "ref-id-1",
      ref_id2: "ref-id-2",
      version: "23"
    }

    assert [expected] == products
  end

  test "get_product_by_id - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/getProductById.xml", fn conn ->
      conn
      |> assert_query(%{"productId" => "1"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <product>
          <creationTime>1483228800000</creationTime>
          <deployed>true</deployed>
          <desc>product-desc</desc>
          <features>
            <feature>
              <id>20</id>
              <name>feature-20</name>
              <ver/>
            </feature>
          </features>
          <id>18</id>
          <lifeCycleStage>Complete</lifeCycleStage>
          <modificationTime>1514764799000</modificationTime>
          <name>TestProduct</name>
          <namespaceId>2</namespaceId>
          <namespaceName>TestNamespace</namespaceName>
          <refId1>ref-id-1</refId1>
          <refId2/>
          <saId>1</saId>
          <ver>6</ver>
        </product>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, product} = ExSCEMS.get_product_by_id(client, 1)

    expected = %Product{
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      deployed: true,
      description: "product-desc",
      id: 18,
      life_cycle_stage: "Complete",
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      name: "TestProduct",
      namespace_id: 2,
      namespace_name: "TestNamespace",
      ref_id1: "ref-id-1",
      ref_id2: "",
      version: "6"
    }

    assert expected == product
  end

  test "get_product_by_name_and_version - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/getProductByNameAndVer.xml", fn conn ->
      conn
      |> assert_query(%{"productName" => "foo", "productVersion" => "bar"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <product>
          <creationTime>1483228800000</creationTime>
          <deployed>true</deployed>
          <desc>product-desc</desc>
          <features>
            <feature>
              <id>20</id>
              <name>feature-20</name>
              <ver/>
            </feature>
          </features>
          <id>18</id>
          <lifeCycleStage>Complete</lifeCycleStage>
          <modificationTime>1514764799000</modificationTime>
          <name>TestProduct</name>
          <namespaceId>2</namespaceId>
          <namespaceName>TestNamespace</namespaceName>
          <refId1>ref-id-1</refId1>
          <refId2/>
          <saId>1</saId>
          <ver>6</ver>
        </product>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, product} =
      ExSCEMS.get_product_by_name_and_version(client, name: "foo", version: "bar")

    expected = %Product{
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      deployed: true,
      description: "product-desc",
      id: 18,
      life_cycle_stage: "Complete",
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      name: "TestProduct",
      namespace_id: 2,
      namespace_name: "TestNamespace",
      ref_id1: "ref-id-1",
      ref_id2: "",
      version: "6"
    }

    assert expected == product
  end

  #
  # Entitlement
  #

  test "create_entitlement - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/createEntitlement.xml", fn conn ->
      conn
      |> assert_request_body(%{
        "startDate" => "2017-01-01",
        "endDate" => "2500-12-31",
        "customerId" => "1",
        "contactEmail" => "1@example.com",
        "isRetail" => "false"
      })
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <eid>d967c7ed-d783-466c-bfe0-96089ec93770</eid>
        <entId>1</entId>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %Response{stat: "ok"}, 1, "d967c7ed-d783-466c-bfe0-96089ec93770"} =
      ExSCEMS.create_entitlement(
        client,
        startDate: "2017-01-01",
        endDate: "2500-12-31",
        customerId: 1,
        contactEmail: "1@example.com",
        isRetail: false
      )
  end

  test "create_entitlement - fail", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/createEntitlement.xml", fn conn ->
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

    {:error,
     %Response{
       error_code: "100",
       error_desc: "The request parameter is not valid.",
       stat: "fail"
     }} = ExSCEMS.create_entitlement(client, [])
  end

  test "search_entitlements - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/searchEntitlements.xml", fn conn ->
      conn
      |> assert_query(%{"pageSize" => "1"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <stat>ok</stat>
        <entitlements>
          <entitlement>
            <entId>1045</entId>
            <eid>0c7532****</eid>
            <entitlementType>enterprise</entitlementType>
            <startDate>2013-12-10</startDate>
            <endDate>2500-12-31</endDate>
            <customer>
              <customerId>123</customerId>
              <customerName>dummy-customer-name</customerName>
              <customerRefId>dummy-customer-ref-id</customerRefId>
            </customer>
            <contact>
              <contactId>150</contactId>
              <contactEmailId>contact@example.com</contactEmailId>
            </contact>
            <alternateEmailId/>
            <state>3</state>
            <status>0</status>
            <refId1>ent_test_133</refId1>
            <refId2/>
            <deploymentType>Cloud</deploymentType>
            <creationTime>1483228800000</creationTime>
            <modificationTime>1514764799000</modificationTime>
            <timezone>(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London</timezone>
          </entitlement>
        </entitlements>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, entitlements} = ExSCEMS.search_entitlements(client, pageSize: 1)

    expected = %Entitlement{
      id: 1045,
      eid: "0c7532****",
      start_date: ~D[2013-12-10],
      end_date: ~D[2500-12-31],
      customer: %Customer{
        id: 123,
        name: "dummy-customer-name",
        customer_ref_id: "dummy-customer-ref-id"
      },
      contact: %Contact{
        id: 150,
        email: "contact@example.com"
      },
      state: 3,
      status: 0,
      ref_id1: "ent_test_133",
      ref_id2: "",
      deployment_type: "Cloud",
      line_items: nil,
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      timezone: "(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London"
    }

    assert [expected] == entitlements
  end

  test "get_entitlement_by_id - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/getEntitlementDetailsById.xml", fn conn ->
      conn
      |> assert_query(%{"entId" => "1045", "fetchCompleteEID" => "true"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <stat>ok</stat>
        <entitlement>
          <entId>1045</entId>
          <eid>0c7532a3-ba97-4310-89c8-77b8e0787e6d</eid>
          <entitlementType>enterprise</entitlementType>
          <startDate>2013-12-10</startDate>
          <endDate>2500-12-31</endDate>
          <customer>
            <customerId>123</customerId>
            <customerName>dummy-customer-name</customerName>
            <customerRefId>dummy-customer-ref-id</customerRefId>
          </customer>
          <contact>
            <contactId>150</contactId>
            <contactEmailId>contact@example.com</contactEmailId>
          </contact>
          <alternateEmailId/>
          <state>3</state>
          <status>0</status>
          <refId1>ent_test_133</refId1>
          <refId2/>
          <deploymentType>Cloud</deploymentType>
          <lineItems>
            <lineItem>
              <lineItemId>234</lineItemId>
              <lineItemName>TestProduct</lineItemName>
              <status>1</status>
              <type>product</type>
              <enforcement>
                <enforcementId>1</enforcementId>
                <enforcementName>Sentinel Cloud</enforcementName>
                <enforcementVersion>3.6.0</enforcementVersion>
              </enforcement>
              <numberOfUsers>1</numberOfUsers>
              <itemProduct>
                <itemFeatureLicenseModels>
                  <itemFeatureLicenseModel>
                    <entFtrLMId>56330</entFtrLMId>
                    <feature>
                      <id>20</id>
                      <featureName>feature-20</featureName>
                      <featureId>4</featureId>
                    </feature>
                    <licenseModel>
                      <licenseModelId>6</licenseModelId>
                      <licenseModelName>TestModel</licenseModelName>
                    </licenseModel>
                  </itemFeatureLicenseModel>
                </itemFeatureLicenseModels>
                <product>
                  <productId>55</productId>
                  <productName>TestProduct</productName>
                  <productVersion>2</productVersion>
                  <refId1>product-ref-id1</refId1>
                  <refId2/>
                </product>
                <itemServiceAgreement>
                    <entProductSAId>1166</entProductSAId>
                    <serviceAgreement>
                    <serviceAgreementId>1</serviceAgreementId>
                    <serviceAgreementName>Service Agreement Template</serviceAgreementName>
                  </serviceAgreement>
                </itemServiceAgreement>
              </itemProduct>
            </lineItem>
          </lineItems>
          <creationTime>1483228800000</creationTime>
          <modificationTime>1514764799000</modificationTime>
          <timezone>(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London</timezone>
        </entitlement>
      </emsResponse>
      """)
    end)

    {:ok, %Response{stat: "ok"}, ent} =
      ExSCEMS.get_entitlement_by_id(client, 1045, fetchCompleteEID: true)

    expected = %Entitlement{
      id: 1045,
      eid: "0c7532a3-ba97-4310-89c8-77b8e0787e6d",
      start_date: ~D[2013-12-10],
      end_date: ~D[2500-12-31],
      customer: %Customer{
        id: 123,
        name: "dummy-customer-name",
        customer_ref_id: "dummy-customer-ref-id"
      },
      contact: %Contact{
        id: 150,
        email: "contact@example.com"
      },
      state: 3,
      status: 0,
      ref_id1: "ent_test_133",
      ref_id2: "",
      deployment_type: "Cloud",
      line_items: [
        %LineItem{
          id: 234,
          status: 1,
          number_of_users: 1,
          feature_license_models: [
            %{
              ent_ftr_lm_id: 56330,
              feature_id: 4,
              feature_name: "feature-20",
              ftr_id: 20,
              license_model_id: 6,
              license_model_name: "TestModel"
            }
          ],
          product: %Product{
            id: 55,
            name: "TestProduct",
            version: "2",
            ref_id1: "product-ref-id1",
            ref_id2: ""
          }
        }
      ],
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z"),
      timezone: "(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London"
    }

    assert expected == ent
  end

  #
  # LineItem
  #

  test "create_line_item - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/addEntitlementItem.xml", fn conn ->
      conn
      |> assert_request_body(%{
        "entId" => "1",
        "productId" => "2"
      })
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <id>1</id>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %Response{stat: "ok"}, 1} =
      ExSCEMS.create_line_item(
        client,
        entId: 1,
        productId: 2
      )
  end

  test "create_line_item - fail", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/addEntitlementItem.xml", fn conn ->
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

    {:error,
     %Response{
       error_code: "100",
       error_desc: "The request parameter is not valid.",
       stat: "fail"
     }} = ExSCEMS.create_line_item(client, [])
  end

  test "search_line_items - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/getEntitlementItemByCriteria.xml", fn conn ->
      conn
      |> assert_query(%{"lastModified" => "1452556494000"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
      <stat>ok</stat>
      <lineItems>
        <lineItem>
          <lineItemId>234</lineItemId>
          <lineItemName>TestProduct</lineItemName>
          <status>1</status>
          <type>service</type>
          <enforcement>
            <enforcementId>1</enforcementId>
            <enforcementName>Sentinel Cloud</enforcementName>
            <enforcementVersion>3.6.0</enforcementVersion>
          </enforcement>
          <entitlement>
            <entId>3966</entId>
            <eid>6f13de****</eid>
            <timezone>(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London</timezone>
          </entitlement>
          <numberOfUsers>1</numberOfUsers>
          <itemProduct>
            <itemFeatureLicenseModels>
              <itemFeatureLicenseModel>
                <entFtrLMId>56330</entFtrLMId>
                <feature>
                  <id>20</id>
                  <featureName>feature-20</featureName>
                  <featureId>4</featureId>
                </feature>
                <licenseModel>
                  <licenseModelId>6</licenseModelId>
                  <licenseModelName>TestModel</licenseModelName>
                </licenseModel>
              </itemFeatureLicenseModel>
            </itemFeatureLicenseModels>
            <product>
              <productId>55</productId>
              <productName>TestProduct</productName>
              <productVersion>2</productVersion>
              <refId1>product-ref-id1</refId1>
              <refId2/>
            </product>
            <itemServiceAgreement>
              <entProductSAId>4679</entProductSAId>
              <serviceAgreement>
                <serviceAgreementId>1</serviceAgreementId>
                <serviceAgreementName>Service Agreement Template</serviceAgreementName>
              </serviceAgreement>
            </itemServiceAgreement>
          </itemProduct>
          <creationTime>1483228800000</creationTime>
          <modificationTime>1514764799000</modificationTime>
        </lineItem>
      </lineItems>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, line_items} =
      ExSCEMS.search_line_items(client, lastModified: 1_452_556_494_000)

    expected = %LineItem{
      id: 234,
      status: 1,
      entitlement: %Entitlement{
        id: 3966,
        eid: "6f13de****",
        timezone: "(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London"
      },
      number_of_users: 1,
      feature_license_models: [
        %{
          ent_ftr_lm_id: 56330,
          feature_id: 4,
          feature_name: "feature-20",
          ftr_id: 20,
          license_model_id: 6,
          license_model_name: "TestModel"
        }
      ],
      product: %Product{
        id: 55,
        name: "TestProduct",
        version: "2",
        ref_id1: "product-ref-id1",
        ref_id2: ""
      },
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z")
    }

    assert [expected] == line_items
  end

  test "get_line_item_by_id - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/getEntitlementItemById.xml", fn conn ->
      conn
      |> assert_query(%{"lineItemId" => "234"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
      <stat>ok</stat>
      <lineItem>
        <lineItemId>234</lineItemId>
        <lineItemName>TestProduct</lineItemName>
        <status>1</status>
        <type>service</type>
        <enforcement>
          <enforcementId>1</enforcementId>
          <enforcementName>Sentinel Cloud</enforcementName>
          <enforcementVersion>3.6.0</enforcementVersion>
        </enforcement>
        <entitlement>
          <entId>3966</entId>
          <eid>6f13de****</eid>
          <timezone>(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London</timezone>
        </entitlement>
        <numberOfUsers>1</numberOfUsers>
        <itemProduct>
          <itemFeatureLicenseModels>
            <itemFeatureLicenseModel>
              <entFtrLMId>56330</entFtrLMId>
              <feature>
                <id>20</id>
                <featureName>feature-20</featureName>
                <featureId>4</featureId>
              </feature>
              <licenseModel>
                <licenseModelId>6</licenseModelId>
                <licenseModelName>TestModel</licenseModelName>
              </licenseModel>
            </itemFeatureLicenseModel>
          </itemFeatureLicenseModels>
          <product>
            <productId>55</productId>
            <productName>TestProduct</productName>
            <productVersion>2</productVersion>
            <refId1>product-ref-id1</refId1>
            <refId2/>
          </product>
          <itemServiceAgreement>
            <entProductSAId>4679</entProductSAId>
            <serviceAgreement>
              <serviceAgreementId>1</serviceAgreementId>
              <serviceAgreementName>Service Agreement Template</serviceAgreementName>
            </serviceAgreement>
          </itemServiceAgreement>
        </itemProduct>
        <creationTime>1483228800000</creationTime>
        <modificationTime>1514764799000</modificationTime>
      </lineItem>
      </emsResponse>
      """)
    end)

    {:ok, %{stat: "ok"}, line_item} = ExSCEMS.get_line_item_by_id(client, 234)

    expected = %LineItem{
      id: 234,
      status: 1,
      entitlement: %Entitlement{
        id: 3966,
        eid: "6f13de****",
        timezone: "(GMT) Greenwich Mean Time, : Dublin, Edinburgh, Lisbon, London"
      },
      number_of_users: 1,
      feature_license_models: [
        %{
          ent_ftr_lm_id: 56330,
          feature_id: 4,
          feature_name: "feature-20",
          ftr_id: 20,
          license_model_id: 6,
          license_model_name: "TestModel"
        }
      ],
      product: %Product{
        id: 55,
        name: "TestProduct",
        version: "2",
        ref_id1: "product-ref-id1",
        ref_id2: ""
      },
      creation_time: parse_iso8601_datetime!("2017-01-01T00:00:00.000Z"),
      modification_time: parse_iso8601_datetime!("2017-12-31T23:59:59.000Z")
    }

    assert expected == line_item
  end

  test "update_line_item - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/updateEntitlementItem.xml", fn conn ->
      conn
      |> assert_request_body(%{
        "lineItemId" => "1",
        "refId1" => "foo"
      })
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %Response{stat: "ok"}} =
      ExSCEMS.update_line_item(
        client,
        lineItemId: 1,
        refId1: "foo"
      )
  end

  test "delete_line_item - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/removeEntitlementItem.xml", fn conn ->
      conn
      |> assert_request_body(%{"lineItemId" => "1"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %Response{stat: "ok"}} = ExSCEMS.delete_line_item(client, 1)
  end

  test "get_line_item_feature_assoc - success", %{bypass: bypass, client: client} do
    xml_str = """
    <?xml version="1.0" encoding="UTF-8"?>
    <emsResponse>
      <stat>ok</stat>
      <lineItem>
        <lineItemId>7938</lineItemId>
        <itemProduct>
          <itemFeatureLicenseModels>
            <itemFeatureLicenseModel>
              <entFtrLMId>56330</entFtrLMId>
              <feature>
                <id>20</id>
                <featureName>feature-20</featureName>
                <featureId>4</featureId>
              </feature>
              <licenseModel>
                <licenseModelId>6</licenseModelId>
                <licenseModelName>TestModel</licenseModelName>
              </licenseModel>
            </itemFeatureLicenseModel>
          </itemFeatureLicenseModels>
          <product>
            <productId>55</productId>
            <productName>TestProduct</productName>
            <productVersion>2</productVersion>
          </product>
        </itemProduct>
      </lineItem>
    </emsResponse>
    """

    Bypass.expect_once(bypass, "GET", "/retrieveFeatureLineItemAssociation.xml", fn conn ->
      conn
      |> assert_query(%{"lineItemId" => "7938"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, xml_str)
    end)

    {:ok, %Response{stat: "ok", body: ^xml_str}} =
      ExSCEMS.get_line_item_feature_assoc(client, 7938)
  end

  test "update_line_item_feature_assoc - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/updateFeatureLineItemAssociation.xml", fn conn ->
      conn
      |> assert_request_body(%{"featureDetails" => "<xml></xml>"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %Response{stat: "ok"}} = ExSCEMS.update_line_item_feature_assoc(client, "<xml></xml>")
  end

  test "get_line_item_feature_lm_assoc - success", %{bypass: bypass, client: client} do
    xml_str = """
    <?xml version="1.0" encoding="UTF-8"?>
    <emsResponse>
      <stat>ok</stat>
      <lineItem>
        <lineItemId>7938</lineItemId>
        <itemProduct>
          <product>
            <productId>55</productId>
            <productName>TestProduct</productName>
            <productVersion>2</productVersion>
          </product>
        </itemProduct>
      </lineItem>
      <features>
        <feature>
          <id>20</id>
          <featureName>feature-20</featureName>
          <licenseModels>
            <licenseModel>
              <licenseModelId>6</licenseModelId>
              <licenseModelName>License Model 6</licenseModelName>
              <licenseModelDescription>description</licenseModelDescription>
              <enfVersion>3.6.0</enfVersion>
              <enfName>3.6.0</enfName>
              <selected>1</selected>
            </licenseModel>
          </licenseModels>
        </feature>
        <feature>
          <id>21</id>
          <featureName>feature-21</featureName>
          <licenseModels>
            <licenseModel>
              <licenseModelId>6</licenseModelId>
              <licenseModelName>License Model 6</licenseModelName>
              <licenseModelDescription>description</licenseModelDescription>
              <enfVersion>3.6.0</enfVersion>
              <enfName>3.6.0</enfName>
              <selected>0</selected>
            </licenseModel>
          </licenseModels>
        </feature>
      </features>
    </emsResponse>
    """

    Bypass.expect_once(bypass, "GET", "/retrieveLineItemFeatureLMAssociation.xml", fn conn ->
      conn
      |> assert_query(%{"lineItemId" => "7938"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, xml_str)
    end)

    {:ok, %Response{stat: "ok", body: ^xml_str}} =
      ExSCEMS.get_line_item_feature_lm_assoc(client, 7938)
  end

  test "update_line_item_feature_lm_assoc - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/updateLineItemFeatureLMAssociation.xml", fn conn ->
      conn
      |> assert_request_body(%{"featureLMDetails" => "<xml></xml>"})
      |> Plug.Conn.put_resp_header("Content-Type", "application/xml;charset=UTF-8")
      |> Plug.Conn.resp(200, """
      <?xml version="1.0" encoding="UTF-8"?>
      <emsResponse>
        <stat>ok</stat>
      </emsResponse>
      """)
    end)

    {:ok, %Response{stat: "ok"}} =
      ExSCEMS.update_line_item_feature_lm_assoc(client, "<xml></xml>")
  end

  #
  # Util
  #

  defp assert_request_body(conn, expected) do
    conn2 = Plug.Parsers.call(conn, Plug.Parsers.init(parsers: [:urlencoded]))
    assert expected == conn2.body_params
    conn
  end

  def assert_query(conn, expected) do
    assert expected == URI.decode_query(conn.query_string)
    conn
  end

  def parse_iso8601_datetime!(string) do
    {:ok, datetime, 0} = DateTime.from_iso8601(string)
    datetime
  end
end
