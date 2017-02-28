defmodule Jerboa.Format.Body.AttributeTest do
  use ExUnit.Case, async: true

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.Lifetime
  alias Jerboa.Params

  import Jerboa.Test.Helper.Attribute, only: [total: 1, length_correct?: 2, type: 1]

  describe "Attribute.encode/2" do

    test "IPv4 XORMappedAddress as a TLV" do
      attr = XORMAHelper.struct(4)

      bin = Attribute.encode %Params{}, attr

      assert type(bin) === 0x0020
      assert length_correct?(bin, total(address: 4, other: 4))
    end

    test "IPv6 XORMappedAddress as a TLV" do
      i = XORMAHelper.i()
      attr = XORMAHelper.struct(6)
      params = %Params{identifier: i}

      bin = Attribute.encode params, attr

      assert type(bin) === 0x0020
      assert length_correct?(bin, total(address: 16, other: 4))
    end

    test "LIFETIME as a TLV" do
      duration = 12_345

      bin = Attribute.encode(Params.new, %Lifetime{duration: duration})

      assert type(bin) == 0x000D
      assert length_correct?(bin, total(duration: 4))
    end
  end
end
