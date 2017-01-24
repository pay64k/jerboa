defmodule Jerboa.FormatTest do
  use ExUnit.Case, async: true
  use Quixir

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.Format
  alias Format.{HeaderLengthError,BodyLengthError}
  alias Format.{First2BitsError,MagicCookieError,UnknownMethodError,Last2BitsError}
  alias Format.Header.{MagicCookie,
                     Type.Method, Type.Class}
  alias Format.Body
  alias Body.Attribute
  alias Jerboa.Params

  import Bitwise

  @i :crypto.strong_rand_bytes(div 96, 8)
  @magic MagicCookie.value
  @most_significant_magic_16 <<(@magic >>> 16) :: 16>>

  describe "Format.encode/1" do

    test "body follows header with length in header" do
      a = XORMAHelper.struct(4)

      bin = Format.encode %Params{
        class: :success,
        method: :binding,
        identifier: @i,
        attributes: [a]}

      assert body_bytes(bin) == 12
    end
  end

  describe "Format.decode/1" do

    test "fails given packet with not enough bytes for header" do
      ptest length: int(min: 0, max: 19), content: int(min: 0) do
        byte_length = length * 8
        packet = <<content::size(byte_length)>>

        assert {:error, %HeaderLengthError{binary: ^packet}} = Format.decode packet
      end
    end

    test "fails given packet not starting with two zeroed bits" do
      ptest first_two: int(min: 1, max: 3), content: int(min: 0),
            length: int(min: 20) do
        bit_length = length * 8 - 2
        packet = <<first_two::2, content::size(bit_length)>>

        {:error, error} = Format.decode packet

        assert %First2BitsError{bits: ^first_two} = error
      end
    end

    test "fails given packet with invalid STUN magic cookie" do
      ptest before_magic: int(min: 0), magic: int(min: 0, max: @magic - 1),
            after_magic: int(min: 0), length: int(min: 12) do
        packet = <<0::2, before_magic::30, magic::32,
                   after_magic::unit(8)-size(length)>>
        <<header::20-bytes, _::binary>> = packet

        {:error, error} = Format.decode packet

        assert %MagicCookieError{header: ^header} = error
      end
    end

    test "fails if length isn't a multiple of 4" do
      ptest length: int(min: 0), content: int(min: 0) do
        length = if rem(length, 4) == 0, do: length + 1, else: length
        packet = <<0::2, 1::14, length::16, @magic::32, 0::96,
                  content::size(length)-unit(8)>>

        {:error, error} = Format.decode packet

        assert %Last2BitsError{length: ^length} = error
      end
    end

    test "fails given packet with invalid STUN method" do
      ptest method: int(min: 1024, max: 4095), class: int(min: 0, max: 3) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        packet = <<0::2, m2::5, c1::1, m1::3, c0::1, m0::4, 0::16,
                   @magic::32, 0::96>>

        {:error, error} = Format.decode packet

        assert %UnknownMethodError{method: ^method} = error
      end
    end

    test "decodes class and method from the header" do
      ptest method: int(min: 1, max: 1), class: int(min: 0, max: 3) do
        bit_class = <<c1::1, c0::1>> = <<class::2>>
        bit_method = <<m2::5, m1::3, m0::4>> = <<method::12>>
        packet = <<0::2, m2::5, c1::1, m1::3, c0::1, m0::4, 0::16,
          @magic::32, 0::96>>
        decoded_class = Class.decode(bit_class)
        {:ok, decoded_method} = Method.decode(bit_method)

        {:ok, message} = Format.decode packet

        assert decoded_method == message.method
        assert decoded_class == message.class
      end
    end

    test "fails given packet with too short message body" do
      ptest method: int(min: 1, max: 1), class: int(min: 0, max: 3),
            length: int(min: 1000), body: int(min: 0),
            body_length: int(min: 0, max: ^length - 1) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        type = <<m2::5, c1::1, m1::3, c0::1, m0::4>>
        packet = <<0::2, type::bits, length::16, @magic::32, 0::96,
                   body::unit(8)-size(body_length)>>

        {:error, error} = Format.decode packet

        assert %BodyLengthError{length: ^body_length} = error
      end
    end

    test "returns bytes after the length given in the header into the `extra` field" do
      ptest method: int(min: 1, max: 1), class: int(min: 0, max: 3),
        extra: string(min: 1) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        type = <<m2::5, c1::1, m1::3, c0::1, m0::4>>
        packet = <<0::2, type::bits, 0::16, @magic::32, 0::96,
          extra::binary>>

        {:ok, message} = Format.decode packet

        assert ^extra = message.extra
      end
    end
  end

  describe "Format.decode!/1" do
    test "raises an exception upon failure" do
      packet = "Supercalifragilisticexpialidocious!"

      assert_raise First2BitsError, fn -> Format.decode!(packet) end
    end

    test "returns value without an :ok tuple" do
      packet = <<0::2, 1::14, 0::16, @magic::32, 0::96>>

      assert %Params{} = Format.decode!(packet)
    end
  end

  defp body_bytes(<<_::16, x::16, _::32, _:: 96, _::size(x)-bytes>>) do
    x
  end
end
