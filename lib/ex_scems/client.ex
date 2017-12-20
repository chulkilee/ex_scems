defmodule ExSCEMS.Client do
  @moduledoc """
  HTTP Client for Sentinel Cloud EMS Web Services.

  - Send request body as form
  - Parse XML response body
  """

  import SweetXml

  alias HTTPoison.Response, as: RawResponse
  alias ExSCEMS.Response

  @default_headers [
    {"user-agent", "ex_scems"}
  ]

  @type response :: Response.t()

  @doc """
  Issues an HTTP request with the given method to the given url.
  """
  def request(method, url, body \\ "", headers \\ [], options \\ [])

  def request(method, url, body, headers, options) when is_map(body) or is_list(body),
    do: request(method, url, {:form, body}, headers, options)

  def request(method, url, body, headers, options) do
    case HTTPoison.request(method, url, body, build_headers(headers, body), options) do
      {:ok, raw_resp} ->
        resp =
          raw_resp
          |> unpack_raw_response()
          |> transform_headers()
          |> build_response()
          |> parse_xml!()

        {:ok, resp}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_headers(headers, ""), do: headers ++ @default_headers

  defp build_headers(headers, _body),
    do: headers ++ @default_headers ++ [{"content-type", "application/x-www-form-urlencoded"}]

  defp unpack_raw_response(%RawResponse{status_code: status_code, headers: headers, body: body}),
    do: {status_code, headers, body}

  defp transform_headers({status_code, headers, body}) do
    headers = Enum.group_by(headers, fn {k, _} -> String.downcase(k) end, fn {_, v} -> v end)
    {status_code, headers, body}
  end

  defp build_response({status_code, headers, body}),
    do: %Response{body: body, headers: headers, status_code: status_code}

  defp parse_xml!(%Response{body: body} = resp) when byte_size(body) == 0, do: resp

  defp parse_xml!(%Response{headers: headers} = resp) do
    case Map.get(headers, "content-type") do
      ["application/xml" <> _] -> do_parse_xml!(resp)
      nil -> resp
    end
  end

  defp do_parse_xml!(%Response{body: body} = resp) do
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
end
