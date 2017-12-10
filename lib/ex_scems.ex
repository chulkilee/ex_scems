defmodule ExSCEMS do
  @moduledoc """
  Documentation for ExSCEMS.
  """

  import SweetXml

  alias ExSCEMS.{Client, Config, Response}

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
  # XML
  #

  defp xml_text(nil), do: nil
  defp xml_text(xml), do: xpath(xml, ~x"//text()"s)
end
