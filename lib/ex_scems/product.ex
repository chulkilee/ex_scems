defmodule ExSCEMS.Product do
  @moduledoc """
  Product
  """

  import SweetXml
  import ExSCEMS.XMLUtil

  defstruct [
    :creation_time,
    :deployed,
    :description,
    :id,
    :life_cycle_stage,
    :modification_time,
    :name,
    :namespace_id,
    :namespace_name,
    :ref_id1,
    :ref_id2,
    :version
  ]

  @type t :: %__MODULE__{
          creation_time: DateTime.t() | nil,
          deployed: boolean() | nil,
          description: String.t() | nil,
          id: integer(),
          life_cycle_stage: String.t() | nil,
          modification_time: DateTime.t() | nil,
          name: String.t(),
          namespace_id: integer() | nil,
          namespace_name: String.t() | nil,
          ref_id1: String.t(),
          ref_id2: String.t(),
          version: String.t()
        }

  def parse_xml(xml) do
    parse_struct(
      __MODULE__,
      xml,
      ~x"//product",
      creation_time: ~x"./creationTime" |> transform_to_datetime(),
      deployed: ~x"./deployed" |> transform_to_boolean(),
      description: ~x"./desc" |> transform_to_string(),
      id: ~x"./id/text()|./productId/text()"io,
      life_cycle_stage: ~x"./lifeCycleStage" |> transform_to_string(),
      modification_time: ~x"./modificationTime" |> transform_to_datetime(),
      name: ~x"./name|./productName" |> transform_to_string(),
      namespace_id: ~x"./namespaceId/text()"io,
      namespace_name: ~x"./namespaceName" |> transform_to_string(),
      ref_id1: ~x"./refId1/text()"s,
      ref_id2: ~x"./refId2/text()"s,
      version: ~x"./ver|./productVersion" |> transform_to_string()
    )
  end
end
