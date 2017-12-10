defmodule ExSCEMS.Config do
  @moduledoc """
  Config for Sentinel Cloud EMS Web Services.
  """

  defstruct session_id: nil, endpoint: nil

  @type t :: %__MODULE__{
          session_id: String.t(),
          endpoint: String.t()
        }
end
