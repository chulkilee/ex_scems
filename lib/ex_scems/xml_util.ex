defmodule ExSCEMS.XMLUtil do
  import SweetXml

  def transform_to_string(sweet_xpath), do: transform_by(sweet_xpath, &xml_text/1)

  def transform_to_date(sweet_xpath),
    do: transform_by(sweet_xpath, fn xml -> xml |> xml_text() |> parse_date!() end)

  def transform_to_datetime(sweet_xpath),
    do: transform_by(sweet_xpath, fn xml -> xml |> xml_text() |> parse_timestamp!() end)

  def transform_to_boolean(sweet_xpath),
    do: transform_by(sweet_xpath, fn xml -> xml |> xml_text() |> parse_boolean!() end)

  def xml_text(nil), do: nil
  def xml_text(xml), do: xpath(xml, ~x"//text()"s)

  def parse_struct(_struct, nil, _sweet_xpath, _subspec), do: nil

  def parse_struct(struct, parent, sweet_xpath, subspec) do
    fields = xpath(parent, sweet_xpath, subspec)
    struct!(struct, fields)
  end

  def parse_collection(nil, _parent_xpath, _element_xpath, _func), do: nil

  def parse_collection(xml, parent_xpath, element_xpath, func) do
    case xpath(xml, parent_xpath) do
      nil -> nil
      found -> found |> xpath(element_xpath) |> Enum.map(func)
    end
  end

  def parse_boolean!(nil), do: nil
  def parse_boolean!("true"), do: true
  def parse_boolean!("false"), do: false

  def parse_date!(nil), do: nil
  def parse_date!(val), do: Date.from_iso8601!(val)

  def parse_timestamp!(nil), do: nil

  def parse_timestamp!(val) do
    {i, ""} = Integer.parse(val)
    DateTime.from_unix!(i, :millisecond)
  end
end
