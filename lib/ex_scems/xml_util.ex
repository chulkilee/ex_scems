defmodule ExSCEMS.XMLUtil do
  import SweetXml

  def xml_text(nil), do: nil
  def xml_text(xml), do: xpath(xml, ~x"//text()"s)
end
