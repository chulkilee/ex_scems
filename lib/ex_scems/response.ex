defmodule ExSCEMS.Response do
  @moduledoc """
  Response of ExSCMES.Client.
  """

  defstruct [
    :status_code,
    :body,
    :body_xml,
    :headers,
    :stat,
    :error_code,
    :error_desc
  ]

  @type t :: %__MODULE__{
          status_code: integer(),
          body: term(),
          stat: String.t(),
          error_code: String.t(),
          error_desc: String.t()
        }
end
