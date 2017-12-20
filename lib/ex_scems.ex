defmodule ExSCEMS do
  @moduledoc """
  Documentation for ExSCEMS.
  """

  import SweetXml
  import ExSCEMS.XMLUtil

  alias ExSCEMS.{Client, Config, Response}
  alias ExSCEMS.{Customer, Product}

  #
  # Request
  #

  def request(method, path, query, body, %Config{endpoint: endpoint, session_id: session_id}) do
    url = build_url(endpoint, path, query)
    headers = [{"Cookie", "JSESSIONID=" <> session_id}]

    case Client.request(method, url, body, headers) do
      {:ok, %Response{stat: "ok"} = resp} -> {:ok, resp}
      {:ok, resp} -> {:error, resp}
      {:error, error} -> {:error, error}
    end
  end

  defp get(config, path, query), do: request(:get, path, query, "", config)

  defp post(config, path, body), do: request(:post, path, [], body, config)

  defp build_url(endpoint, path, []), do: endpoint <> path
  defp build_url(endpoint, path, query), do: endpoint <> path <> "?" <> URI.encode_query(query)

  #
  # Authentication
  #

  @doc """
  [Vendor Login](http://documentation.sentinelcloud.com/wsg/verifyLogin.htm)
  """
  @spec login_by_vendor(String.t(), String.t(), String.t()) ::
          {:ok, Response.t(), String.t()} | {:error, Response.t() | any}
  def login_by_vendor(endpoint, username, password),
    do: do_login(endpoint, "/verifyLogin.xml", userName: username, password: password)

  @doc """
  [Customer Login By EID](http://documentation.sentinelcloud.com/wsg/loginByEID.htm)
  """
  @spec login_by_eid(String.t(), String.t()) ::
          {:ok, Response.t(), String.t()} | {:error, Response.t() | any}
  def login_by_eid(endpoint, eid), do: do_login(endpoint, "/loginByEID.xml", eid: eid)

  @doc """
  [Customer Contact Login by User ID and Password](http://documentation.sentinelcloud.com/wsg/loginByContact.htm)
  """
  @spec login_by_contact(String.t(), String.t(), String.t()) ::
          {:ok, Response.t(), String.t()} | {:error, Response.t() | any}
  def login_by_contact(endpoint, email, password),
    do: do_login(endpoint, "/loginByContact.xml", emailId: email, password: password)

  defp do_login(endpoint, path, form) do
    case Client.request(:post, build_url(endpoint, path, []), {:form, form}, [], []) do
      {:ok, resp} -> parse_login_response(resp)
      {:error, error} -> {:error, error}
    end
  end

  defp parse_login_response(%Response{body_xml: body_xml} = resp) do
    case body_xml
         |> xpath(~x"/emsResponse/sessionId")
         |> xml_text() do
      nil -> {:error, resp}
      val -> {:ok, resp, val}
    end
  end

  #
  # Customer
  #

  @doc """
  Create a customer with the given parameters.

  [Create Customer](http://documentation.sentinelcloud.com/wsg/createCustomer.htm)
  """
  def create_customer(form, config) do
    case post(config, "/createCustomer.xml", form) do
      {:ok, resp} -> {:ok, resp, xpath(resp.body_xml, ~x"//customerId/text()"i)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Delete a customer with the given id.

  [Delete Customer](http://documentation.sentinelcloud.com/wsg/deleteCustomerById.htm)
  """
  @spec delete_customer(String.t(), Config.t()) :: {:ok, Response.t()} | {:error, any}
  def delete_customer(id, config), do: post(config, "/deleteCustomerById.xml", customerId: id)

  @doc """
  Retrieve details for a customer using customer ID.

  http://documentation.sentinelcloud.com/wsg/getCustomerById.htm
  """
  def get_customer_by_id(id, config) do
    case get(config, "/getCustomerById.xml", customerId: id) do
      {:ok, resp} -> {:ok, resp, Customer.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieves customer details by using customer reference ID.

  [Retrieve Customer by Customer Ref ID](http://documentation.sentinelcloud.com/wsg/getCustomerByCustomerRefId.htm)
  """
  def get_customer_by_customer_ref_id(id, config) do
    case get(config, "/getCustomerByCustomerRefId.xml", customerRefId: id) do
      {:ok, resp} -> {:ok, resp, Customer.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  #
  # Product
  #

  @doc """
  [Create Product](http://documentation.sentinelcloud.com/wsg/createProduct.htm)
  """
  def create_product(form, config) do
    case post(config, "/createProduct.xml", form) do
      {:ok, resp} -> {:ok, resp, xpath(resp.body_xml, ~x"//productId/text()"i)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve the list of products against the query parameters.

  [Search Products](http://documentation.sentinelcloud.com/WSG/searchProducts.htm)
  """
  def search_products(options, config) do
    case get(config, "/searchProducts.xml", options) do
      {:ok, resp} -> {:ok, resp, parse_products(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  defp parse_products(xml),
    do: parse_collection(xml, ~x"//products", ~x"//product"l, &Product.parse_xml/1)

  @doc """
  Retrieve the details of a product for a given product ID.

  [Retrieve Product Details by productId](http://documentation.sentinelcloud.com/WSG/getProductById.htm)
  """
  def get_product_by_id(id, config) do
    case get(config, "/getProductById.xml", productId: id) do
      {:ok, resp} -> {:ok, resp, Product.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve product details for the given product name and version.

  [Retrieve Product Details By Name and Version](http://documentation.sentinelcloud.com/WSG/getProductByNameAndVer.htm)
  """
  def get_product_by_name_and_version([name: name, version: version], config) do
    case get(config, "/getProductByNameAndVer.xml", productName: name, productVersion: version) do
      {:ok, resp} -> {:ok, resp, Product.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  #
  # Entitlement
  #

  @doc """
  Create an entitlement with the given parameters.

  [Create Entitlement Using Parameters](http://documentation.sentinelcloud.com/wsg/createEntitlement.htm)
  """
  def create_entitlement(form, config) do
    case post(config, "/createEntitlement.xml", form) do
      {:ok, resp} ->
        {
          :ok,
          resp,
          xpath(resp.body_xml, ~x"//entId/text()"i),
          xpath(resp.body_xml, ~x"//eid/text()"s)
        }

      {:error, error} ->
        {:error, error}
    end
  end
end
