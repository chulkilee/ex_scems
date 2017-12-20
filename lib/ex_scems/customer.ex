defmodule ExSCEMS.Customer do
  @moduledoc """
  Customer
  """

  import SweetXml
  import ExSCEMS.XMLUtil

  alias ExSCEMS.Contact

  defstruct [
    :creation_time,
    :customer_ref_id,
    :description,
    :enabled,
    :id,
    :modification_time,
    :name,
    :ref_id,
    :timezone,

    # assoc
    :contacts
  ]

  @type t :: %__MODULE__{
          creation_time: DateTime.t() | nil,
          customer_ref_id: String.t(),
          description: String.t() | nil,
          enabled: boolean() | nil,
          id: integer(),
          modification_time: DateTime.t() | nil,
          name: String.t(),
          ref_id: String.t() | nil,
          timezone: String.t() | nil,

          # assoc
          contacts: list(Contact.t()) | nil
        }

  def parse_xml(xml) do
    parse_struct(
      __MODULE__,
      xml,
      ~x"//customer",
      contacts: ~x"./contacts" |> transform_by(&parse_contacts/1),
      creation_time: ~x"./creationTime" |> transform_to_datetime(),
      customer_ref_id: ~x"./customerRefId/text()"s,
      description: ~x"./desc" |> transform_to_string(),
      enabled: ~x"./enabled" |> transform_to_boolean(),
      id: ~x"./customerId/text()"i,
      modification_time: ~x"./modificationTime" |> transform_to_datetime(),
      name: ~x"./customerName/text()"s,
      ref_id: ~x"./refId" |> transform_to_string(),
      timezone: ~x"./timezone" |> transform_to_string()
    )
  end

  defp parse_contacts(xml),
    do: parse_collection(xml, ~x"//contacts", ~x"//contact"l, &Contact.parse_xml/1)
end
