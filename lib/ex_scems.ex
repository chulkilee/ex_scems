defmodule ExSCEMS do
  @moduledoc """
  Documentation for ExSCEMS.
  """

  alias ExSCEMS.{Client, Config}

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
end
