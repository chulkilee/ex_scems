defmodule ExSCEMS.Contact do
  @moduledoc """
  Contact
  """

  import SweetXml
  import ExSCEMS.XMLUtil

  defstruct [
    :creation_time,
    :email,
    :id,
    :modification_time,
    :name
  ]

  @type t :: %__MODULE__{
          creation_time: DateTime.t() | nil,
          email: String.t(),
          id: integer(),
          modification_time: DateTime.t() | nil,
          name: String.t()
        }

  def parse_xml(xml) do
    parse_struct(
      __MODULE__,
      xml,
      ~x"/contact",
      creation_time: ~x"./creationTime" |> transform_to_datetime(),
      email: ~x"./contactEmail/text()|./contactEmailId/text()"s,
      id: ~x"./contactId/text()"i,
      modification_time: ~x"./modificationTime" |> transform_to_datetime(),
      name: ~x"./contactName" |> transform_to_string()
    )
  end
end
