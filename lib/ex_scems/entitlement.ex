defmodule ExSCEMS.Entitlement do
  @moduledoc """
  Entitlement
  """

  import SweetXml
  import ExSCEMS.XMLUtil

  alias ExSCEMS.{Contact, Customer, LineItem}

  defstruct [
    :creation_time,
    :deployment_type,
    :eid,
    :end_date,
    :id,
    :modification_time,
    :ref_id1,
    :ref_id2,
    :start_date,
    :state,
    :status,
    :timezone,

    # assoc
    :contact,
    :customer,
    :line_items
  ]

  @type t :: %__MODULE__{
          creation_time: DateTime.t() | nil,
          deployment_type: String.t() | nil,
          eid: String.t(),
          end_date: Date.t() | nil,
          id: integer(),
          modification_time: DateTime.t() | nil,
          ref_id1: String.t() | nil,
          ref_id2: String.t() | nil,
          start_date: Date.t() | nil,
          state: integer() | nil,
          status: integer() | nil,
          timezone: String.t(),

          # assoc
          contact: Contact.t() | nil,
          customer: Customer.t() | nil,
          line_items: list(LineItem.t()) | nil
        }

  def parse_xml(xml) do
    parse_struct(
      __MODULE__,
      xml,
      ~x"//entitlement",
      id: ~x"./entId/text()"i,
      eid: ~x"./eid/text()"s,
      start_date: ~x"./startDate" |> transform_to_date(),
      end_date: ~x"./endDate" |> transform_to_date(),
      customer: ~x"./customer" |> transform_by(&Customer.parse_xml/1),
      contact: ~x"./contact" |> transform_by(&Contact.parse_xml/1),
      ref_id1: ~x"./refId1" |> transform_to_string(),
      ref_id2: ~x"./refId2" |> transform_to_string(),
      deployment_type: ~x"./deploymentType" |> transform_to_string(),
      line_items: ~x"./lineItems" |> transform_by(&parse_line_items/1),
      state: ~x"./state/text()"io,
      status: ~x"./status/text()"io,
      timezone: ~x"./timezone/text()"s,
      creation_time: ~x"./creationTime" |> transform_to_datetime(),
      modification_time: ~x"./modificationTime" |> transform_to_datetime()
    )
  end

  defp parse_line_items(xml),
    do: parse_collection(xml, ~x"//lineItems", ~x"//lineItem"l, &LineItem.parse_xml/1)
end
