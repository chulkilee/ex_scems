defmodule ExSCEMS do
  @moduledoc """
  Documentation for ExSCEMS.
  """

  import SweetXml
  import ExSCEMS.XMLUtil

  alias ExSCEMS.{Client, Config, Response}
  alias ExSCEMS.{Customer, Entitlement, LineItem, Product}

  #
  # Request
  #

  def request(%Config{endpoint: endpoint, session_id: session_id}, method, path, query, body) do
    url = build_url(endpoint, path, query)
    headers = [{"Cookie", "JSESSIONID=" <> session_id}]

    case Client.request(method, url, body, headers) do
      {:ok, %Response{stat: "ok"} = resp} -> {:ok, resp}
      {:ok, resp} -> {:error, resp}
      {:error, error} -> {:error, error}
    end
  end

  defp get(config, path, query), do: request(config, :get, path, query, "")

  defp post(config, path, body), do: request(config, :post, path, [], body)

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
  def create_customer(config, form) do
    case post(config, "/createCustomer.xml", form) do
      {:ok, resp} -> {:ok, resp, xpath(resp.body_xml, ~x"//customerId/text()"i)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Delete a customer with the given id.

  [Delete Customer](http://documentation.sentinelcloud.com/wsg/deleteCustomerById.htm)
  """
  @spec delete_customer(Config.t(), String.t()) :: {:ok, Response.t()} | {:error, any}
  def delete_customer(config, id), do: post(config, "/deleteCustomerById.xml", customerId: id)

  @doc """
  Search customers/view all customers for the given query parameters.

  [Search Customers](http://documentation.sentinelcloud.com/wsg/searchCustomers.htm)
  """
  def search_customers(config, options \\ []) do
    case get(config, "/searchCustomers.xml", options) do
      {:ok, resp} -> {:ok, resp, parse_customers(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve details of a customer using exact customer name.
  [Retrieve Customer Details by Name](http://documentation.sentinelcloud.com/wsg/getCustomerByCustomerNam.htm)
  """
  def search_customers_by_name(config, name) do
    case get(config, "/getCustomerByCustomerName.xml", customerName: name) do
      {:ok, resp} -> {:ok, resp, parse_customers(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  defp parse_customers(xml),
    do: parse_collection(xml, ~x"//customers", ~x"//customer"l, &Customer.parse_xml/1)

  @doc """
  Retrieve details for a customer using customer ID.

  http://documentation.sentinelcloud.com/wsg/getCustomerById.htm
  """
  def get_customer_by_id(config, id) do
    case get(config, "/getCustomerById.xml", customerId: id) do
      {:ok, resp} -> {:ok, resp, Customer.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieves customer details by using customer reference ID.

  [Retrieve Customer by Customer Ref ID](http://documentation.sentinelcloud.com/wsg/getCustomerByCustomerRefId.htm)
  """
  def get_customer_by_customer_ref_id(config, id) do
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
  def create_product(config, form) do
    case post(config, "/createProduct.xml", form) do
      {:ok, resp} -> {:ok, resp, xpath(resp.body_xml, ~x"//productId/text()"i)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve the list of products against the query parameters.

  [Search Products](http://documentation.sentinelcloud.com/WSG/searchProducts.htm)
  """
  def search_products(config, options) do
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
  def get_product_by_id(config, id) do
    case get(config, "/getProductById.xml", productId: id) do
      {:ok, resp} -> {:ok, resp, Product.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve product details for the given product name and version.

  [Retrieve Product Details By Name and Version](http://documentation.sentinelcloud.com/WSG/getProductByNameAndVer.htm)
  """
  def get_product_by_name_and_version(config, name: name, version: version) do
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
  def create_entitlement(config, form) do
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

  @doc """
  Search entitlements by the given query parameters

  [Search Entitlements](http://documentation.sentinelcloud.com/WSG/searchEntitlements.htm)
  """
  def search_entitlements(config, options) do
    case get(config, "/searchEntitlements.xml", options) do
      {:ok, resp} ->
        {
          :ok,
          resp,
          parse_collection(
            resp.body_xml,
            ~x"//entitlements",
            ~x"//entitlement"l,
            &Entitlement.parse_xml/1
          )
        }

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Retrieves the list of line items, with product(s), features(s), and license model, for a given entitlement ID.

  [Retrieve Details of an Entitlement](http://documentation.sentinelcloud.com/wsg/getEntitlementDetailsbyID.htm)
  """
  def get_entitlement_by_id(config, id, options) do
    case get(config, "/getEntitlementDetailsById.xml", Keyword.put_new(options, :entId, id)) do
      {:ok, resp} -> {:ok, resp, Entitlement.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  #
  # LineItem
  #

  @doc """
  [Add a Product to an Entitlement](http://documentation.sentinelcloud.com/WSG/addEntitlementItem.htm)
  """
  def create_line_item(config, options) do
    case post(config, "/addEntitlementItem.xml", options) do
      {:ok, resp} -> {:ok, resp, xpath(resp.body_xml, ~x"//id/text()"i)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieves line Item details based on the specified criteria.

  [Retrieve Line Item Details By Criteria](http://documentation.sentinelcloud.com/WSG/getEntitlementItemByCriteria.htm)
  """
  def search_line_items(config, options) do
    case get(config, "/getEntitlementItemByCriteria.xml", options) do
      {:ok, resp} ->
        {
          :ok,
          resp,
          parse_collection(
            resp.body_xml,
            ~x"//lineItems",
            ~x"//lineItem"l,
            &LineItem.parse_xml/1
          )
        }

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Retrieve entitlement line item details by lineItemId.

  [Retrieve Entitlement Line Item Details](http://documentation.sentinelcloud.com/WSG/getEntitlementItemById.htm)
  """
  def get_line_item_by_id(config, id) do
    case get(config, "/getEntitlementItemById.xml", lineItemId: id) do
      {:ok, resp} -> {:ok, resp, LineItem.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  [Update Entitlement Line Items](http://documentation.sentinelcloud.com/WSG/updateEntitlementItem.htm)
  """
  def update_line_item(config, form), do: post(config, "/updateEntitlementItem.xml", form)

  @doc """
  [Remove Entitlement Line Item](http://documentation.sentinelcloud.com/WSG/removeEntitlementItem.htm)
  """
  def delete_line_item(config, id), do: post(config, "/removeEntitlementItem.xml", lineItemId: id)

  @doc """
  [Retrieve Entitlement Line Item Feature Association](http://documentation.sentinelcloud.com/WSG/retrieveFeatureLineItemAssociation.htm)
  """
  def get_line_item_feature_assoc(config, id),
    do: get(config, "/retrieveFeatureLineItemAssociation.xml", lineItemId: id)

  @doc """
  [Update Line Item Feature Association](http://documentation.sentinelcloud.com/WSG/updateFeatureLineItemAssociation.htm)
  """
  def update_line_item_feature_assoc(config, xml_string),
    do: post(config, "/updateFeatureLineItemAssociation.xml", featureDetails: xml_string)

  @doc """
  [Retrieve Entitlement Line Item Feature License Model Association](http://documentation.sentinelcloud.com/WSG/retrieveLineItemFeatureLMAssociation.htm)
  """
  def get_line_item_feature_lm_assoc(config, id),
    do: get(config, "/retrieveLineItemFeatureLMAssociation.xml", lineItemId: id)

  @doc """
  [Update Line Item Feature License Model Association](http://documentation.sentinelcloud.com/WSG/updateLineItemFeatureLMAssociation.htm)
  """
  def update_line_item_feature_lm_assoc(config, xml_string),
    do: post(config, "/updateLineItemFeatureLMAssociation.xml", featureLMDetails: xml_string)

  #
  # Feature
  #

  @doc """
  [Retrieve Feature By Criteria](http://documentation.sentinelcloud.com/WSG/featureList.htm)
  """
  # TODO: parse
  def create_feature(config, form), do: post(config, "/featureList.xml", form)
end
