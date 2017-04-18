defmodule Jerboa.Client.Protocol.Allocate do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.XORMappedAddress, as: XMA
  alias Jerboa.Format.Body.Attribute.XORRelayedAddress, as: XRA
  alias Jerboa.Format.Body.Attribute.{RequestedTransport, Lifetime, Realm,
                                      Nonce, ErrorCode}
  alias Jerboa.Client
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Credentials

  @spec request(Credentials.t) :: Protocol.request
  def request(creds) do
    params = params(creds)
    Protocol.encode_request(params, creds)
  end

  @spec eval_response(response :: Params.t, Credentials.t)
    :: {:ok, relayed_address :: Client.address, lifetime :: non_neg_integer}
     | {:error, Client.error, Credentials.t}
  def eval_response(params, creds) do
    with :allocate <- Params.get_method(params),
         :success <- Params.get_class(params),
         %{address: raddr, port: rport, family: :ipv4} <- Params.get_attr(params, XRA),
         %XMA{} <- Params.get_attr(params, XMA),
         %{duration: lifetime} <- Params.get_attr(params, Lifetime) do
      relayed_address = {raddr, rport}
      {:ok, relayed_address, lifetime}
    else
      :failure ->
        eval_failure(params, creds)
      _ ->
        {:error, :bad_response, creds}
    end
  end

  @spec params(Credentials.t) :: Params.t
  defp params(creds) do
    creds
    |> Protocol.base_params()
    |> Params.put_class(:request)
    |> Params.put_method(:allocate)
    |> Params.put_attr(%RequestedTransport{})
  end

  @spec eval_failure(resp :: Params.t, Credentials.t)
    :: {:error, Client.error, Credentials.t}
  defp eval_failure(params, creds) do
    realm_attr = Params.get_attr(params, Realm)
    nonce_attr = Params.get_attr(params, Nonce)
    error = Params.get_attr(params, ErrorCode)
    cond do
      is_nil error ->
        {:error, :bad_response, creds}
      should_finalize_creds?(creds, error.name, realm_attr, nonce_attr) ->
        new_creds =
          Credentials.finalize(creds, realm_attr.value, nonce_attr.value)
        {:error, error.name, new_creds}
      error.name == :stale_nonce && nonce_attr ->
        new_creds = %{creds | nonce: nonce_attr.value}
        {:error, error.name, new_creds}
      true ->
        {:error, error.name, creds}
    end
    end

  @spec should_finalize_creds?(Credentials.t, ErrorCode.name,
    Realm.t | nil, Nonce.t | nil) :: boolean
  defp should_finalize_creds?(creds, :unauthorized, %Realm{}, %Nonce{}) do
    not Credentials.complete?(creds)
  end
  defp should_finalize_creds?(_, _, _, _), do: false
end