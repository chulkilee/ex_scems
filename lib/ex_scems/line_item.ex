defmodule ExSCEMS.LineItem do
  @moduledoc """
  Entitlement
  """

  import SweetXml
  import ExSCEMS.XMLUtil

  alias ExSCEMS.{Entitlement, Product}

  defstruct [
    :creation_time,
    :enforcement,
    :id,
    :modification_time,
    :number_of_users,
    :status,

    # assoc
    :entitlement,
    :feature_license_models,
    :product
  ]

  @type t :: %__MODULE__{
          creation_time: DateTime.t() | nil,
          id: integer(),
          modification_time: DateTime.t() | nil,
          number_of_users: integer(),
          status: integer(),

          # assoc
          entitlement: Entitlement.t() | nil,
          feature_license_models: any() | nil,
          product: Product.t() | nil
        }

  def parse_xml(xml) do
    parse_struct(
      __MODULE__,
      xml,
      ~x"//lineItem",
      id: ~x"./lineItemId/text()"i,
      status: ~x"./status/text()"i,
      entitlement: ~x"./entitlement" |> transform_by(&Entitlement.parse_xml/1),
      number_of_users: ~x"./numberOfUsers/text()"i,
      feature_license_models:
        ~x"./itemProduct/itemFeatureLicenseModels"
        |> transform_by(&parse_feature_license_models/1),
      product: ~x"./itemProduct/product" |> transform_by(&Product.parse_xml/1),
      creation_time: ~x"./creationTime" |> transform_to_datetime(),
      modification_time: ~x"./modificationTime" |> transform_to_datetime
    )
  end

  defp parse_feature_license_models(xml) do
    parse_collection(
      xml,
      ~x"//itemFeatureLicenseModels",
      ~x"//itemFeatureLicenseModel"l,
      &parse_feature_license_model/1
    )
  end

  defp parse_feature_license_model(xml) do
    xpath(
      xml,
      ~x"//itemFeatureLicenseModel",
      ent_ftr_lm_id: ~x"./entFtrLMId/text()"i,
      ftr_id: ~x"./feature/id/text()"i,
      feature_name: ~x"./feature/featureName/text()"s,
      feature_id: ~x"./feature/featureId/text()"i,
      license_model_id: ~x"./licenseModel/licenseModelId/text()"i,
      license_model_name: ~x"./licenseModel/licenseModelName/text()"s
    )
  end
end
