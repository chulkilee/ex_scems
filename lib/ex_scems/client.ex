defmodule ExSCEMS.Client do
  @moduledoc """
  HTTP Client for Sentinel Cloud EMS Web Services.

  - Send request body as form
  - Parse XML response body
  """

  require Tesla

  import SweetXml

  alias Tesla.Env, as: RawResponse
  alias Tesla.Middleware
  alias ExSCEMS.Response

  def build_client(endpoint) do
    Tesla.build_client([
      {Middleware.BaseUrl, endpoint},
      Middleware.FormUrlencoded,
      Middleware.Logger,
      Middleware.DebugLogger,
      {Middleware.Headers, %{"user-agent" => "ex_scems"}}
    ])
  end

  def build_client(endpoint, session_id) do
    Tesla.build_client([
      {Middleware.BaseUrl, endpoint},
      Middleware.FormUrlencoded,
      Middleware.Logger,
      Middleware.DebugLogger,
      {Middleware.Headers,
       %{"Cookie" => "JSESSIONID= " <> session_id, "user-agent" => "ex_scems"}}
    ])
  end

  def request(client, opts) do
    client
    |> Tesla.request(opts)
    |> to_response()
    |> parse_xml()
    |> to_tuple()
  rescue
    ex in Tesla.Error ->
      {:error, ex}
  end

  defp to_response(%RawResponse{status: status, headers: headers, body: body}),
    do: %Response{body: body, headers: headers, status_code: status}

  defp parse_xml(
         %Response{headers: %{"content-type" => "application/xml" <> _}, body: body} = resp
       )
       when byte_size(body) > 0 do
    body_xml = parse(body)

    map =
      body_xml
      |> xpath(
        ~x"/emsResponse",
        stat: ~x"./stat/text()"s,
        # error
        error_code: ~x"./code/text()"s,
        error_desc: ~x"./desc/text()"s,
        # search
        total: ~x"./total/text()"s
      )
      |> Map.put(:body_xml, body_xml)

    struct(resp, map)
  end

  defp parse_xml(resp), do: resp

  def to_tuple(%Response{stat: "ok"} = resp), do: {:ok, resp}
  def to_tuple(other), do: {:error, other}
end
