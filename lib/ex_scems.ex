defmodule ExSCEMS do
  @moduledoc """
  Documentation for ExSCEMS.
  """

  require Tesla

  import SweetXml
  import ExSCEMS.XMLUtil

  alias ExSCEMS.{Client, Response}
  alias ExSCEMS.{Customer, Entitlement, LineItem, Product}

  #
  # Request
  #

  def build_client(endpoint, session_id), do: Client.build_client(endpoint, session_id)

  @doc """
  Issues an HTTP request with the given method to the given url.
  """
  def request(client, opts), do: Client.request(client, opts)

  defp get(client, path, query), do: request(client, method: :get, url: path, query: query)

  defp post(client, path, body), do: request(client, method: :post, url: path, body: body)

  #
  # Authentication
  #

  @doc """
  [Vendor Login](http://documentation.sentinelcloud.com/wsg/verifyLogin.htm)
  """
  def login_by_vendor(endpoint, username, password),
    do: do_login(endpoint, "/verifyLogin.xml", userName: username, password: password)

  @doc """
  [Customer Login By EID](http://documentation.sentinelcloud.com/wsg/loginByEID.htm)
  """
  def login_by_eid(endpoint, eid), do: do_login(endpoint, "/loginByEID.xml", eid: eid)

  @doc """
  [Customer Contact Login by User ID and Password](http://documentation.sentinelcloud.com/wsg/loginByContact.htm)
  """
  def login_by_contact(endpoint, email, password),
    do: do_login(endpoint, "/loginByContact.xml", emailId: email, password: password)

  defp do_login(endpoint, path, form) do
    case post(Client.build_client(endpoint), path, form) do
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
  def create_customer(client, form) do
    case post(client, "/createCustomer.xml", form) do
      {:ok, resp} -> {:ok, resp, xpath(resp.body_xml, ~x"//customerId/text()"i)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Delete a customer with the given id.

  [Delete Customer](http://documentation.sentinelcloud.com/wsg/deleteCustomerById.htm)
  """
  def delete_customer(client, id), do: post(client, "/deleteCustomerById.xml", customerId: id)

  @doc """
  Search customers/view all customers for the given query parameters.

  [Search Customers](http://documentation.sentinelcloud.com/wsg/searchCustomers.htm)
  """
  def search_customers(client, options \\ []) do
    case get(client, "/searchCustomers.xml", options) do
      {:ok, resp} -> {:ok, resp, parse_customers(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve details of a customer using exact customer name.
  [Retrieve Customer Details by Name](http://documentation.sentinelcloud.com/wsg/getCustomerByCustomerNam.htm)
  """
  def search_customers_by_name(client, name) do
    case get(client, "/getCustomerByCustomerName.xml", customerName: name) do
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
  def get_customer_by_id(client, id) do
    case get(client, "/getCustomerById.xml", customerId: id) do
      {:ok, resp} -> {:ok, resp, Customer.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieves customer details by using customer reference ID.

  [Retrieve Customer by Customer Ref ID](http://documentation.sentinelcloud.com/wsg/getCustomerByCustomerRefId.htm)
  """
  def get_customer_by_customer_ref_id(client, id) do
    case get(client, "/getCustomerByCustomerRefId.xml", customerRefId: id) do
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
  def create_product(client, form) do
    case post(client, "/createProduct.xml", form) do
      {:ok, resp} -> {:ok, resp, xpath(resp.body_xml, ~x"//productId/text()"i)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve the list of products against the query parameters.

  [Search Products](http://documentation.sentinelcloud.com/WSG/searchProducts.htm)
  """
  def search_products(client, options) do
    case get(client, "/searchProducts.xml", options) do
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
  def get_product_by_id(client, id) do
    case get(client, "/getProductById.xml", productId: id) do
      {:ok, resp} -> {:ok, resp, Product.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve product details for the given product name and version.

  [Retrieve Product Details By Name and Version](http://documentation.sentinelcloud.com/WSG/getProductByNameAndVer.htm)
  """
  def get_product_by_name_and_version(client, name: name, version: version) do
    case get(client, "/getProductByNameAndVer.xml", productName: name, productVersion: version) do
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
  def create_entitlement(client, form) do
    case post(client, "/createEntitlement.xml", form) do
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
  def search_entitlements(client, options) do
    case get(client, "/searchEntitlements.xml", options) do
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
  def get_entitlement_by_id(client, id, options) do
    case get(client, "/getEntitlementDetailsById.xml", Keyword.put_new(options, :entId, id)) do
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
  def create_line_item(client, options) do
    case post(client, "/addEntitlementItem.xml", options) do
      {:ok, resp} -> {:ok, resp, xpath(resp.body_xml, ~x"//id/text()"i)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieves line Item details based on the specified criteria.

  [Retrieve Line Item Details By Criteria](http://documentation.sentinelcloud.com/WSG/getEntitlementItemByCriteria.htm)
  """
  def search_line_items(client, options) do
    case get(client, "/getEntitlementItemByCriteria.xml", options) do
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
  def get_line_item_by_id(client, id) do
    case get(client, "/getEntitlementItemById.xml", lineItemId: id) do
      {:ok, resp} -> {:ok, resp, LineItem.parse_xml(resp.body_xml)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  [Update Entitlement Line Items](http://documentation.sentinelcloud.com/WSG/updateEntitlementItem.htm)
  """
  def update_line_item(client, form), do: post(client, "/updateEntitlementItem.xml", form)

  @doc """
  [Remove Entitlement Line Item](http://documentation.sentinelcloud.com/WSG/removeEntitlementItem.htm)
  """
  def delete_line_item(client, id), do: post(client, "/removeEntitlementItem.xml", lineItemId: id)

  @doc """
  [Retrieve Entitlement Line Item Feature Association](http://documentation.sentinelcloud.com/WSG/retrieveFeatureLineItemAssociation.htm)
  """
  def get_line_item_feature_assoc(client, id),
    do: get(client, "/retrieveFeatureLineItemAssociation.xml", lineItemId: id)

  @doc """
  [Update Line Item Feature Association](http://documentation.sentinelcloud.com/WSG/updateFeatureLineItemAssociation.htm)
  """
  def update_line_item_feature_assoc(client, xml_string),
    do: post(client, "/updateFeatureLineItemAssociation.xml", featureDetails: xml_string)

  @doc """
  [Retrieve Entitlement Line Item Feature License Model Association](http://documentation.sentinelcloud.com/WSG/retrieveLineItemFeatureLMAssociation.htm)
  """
  def get_line_item_feature_lm_assoc(client, id),
    do: get(client, "/retrieveLineItemFeatureLMAssociation.xml", lineItemId: id)

  @doc """
  [Update Line Item Feature License Model Association](http://documentation.sentinelcloud.com/WSG/updateLineItemFeatureLMAssociation.htm)
  """
  def update_line_item_feature_lm_assoc(client, xml_string),
    do: post(client, "/updateLineItemFeatureLMAssociation.xml", featureLMDetails: xml_string)

  #
  # Feature
  #

  @doc """
  [Retrieve Feature By Criteria](http://documentation.sentinelcloud.com/WSG/featureList.htm)
  """
  # TODO: parse
  def create_feature(client, form), do: post(client, "/featureList.xml", form)
end
