defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """
  STUN protocol attributes
  """

  alias Jerboa.Format.ComprehensionError
  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime}

  defprotocol Encoder do
    @moduledoc false

    @spec type_code(t) :: integer
    def type_code(attr)

    @spec encode(t, Params.t) :: binary
    def encode(attr, params)
  end

  defprotocol Decoder do
    @moduledoc false

    @spec decode(type :: t, value :: binary, params :: Params.t)
      :: {:ok, t} | {:error, struct}
    def decode(type, value, params)
  end

  @known_attrs [XORMappedAddress, Lifetime]

  @biggest_16 65_535

  @type t :: struct

  @doc """
  Retrieves attribute name from attribute struct
  """
  @spec name(t) :: module
  def name(%{__struct__: name}), do: name

  @doc false
  @spec encode(Params.t, struct) :: binary
  def encode(params, attr) do
    encode_(Encoder.type_code(attr),
      Encoder.encode(attr, params))
  end

  @doc false
  @spec decode(Params.t, type :: non_neg_integer, value :: binary)
    :: {:ok, t} | {:error, struct} | :ignore
  for attr <- @known_attrs do
    type = Encoder.type_code(struct(attr))
    def decode(params, unquote(type), value) do
      Decoder.decode(struct(unquote(attr)), value, params)
    end
  end
  def decode(_, type, _) when type in 0x0000..0x7FFF do
    {:error, ComprehensionError.exception(attribute: type)}
  end
  def decode(_, _, _), do: :ignore

  defp encode_(type, value) when byte_size(value) < @biggest_16 do
    <<type::16, byte_size(value)::16, value::binary>>
  end
end
