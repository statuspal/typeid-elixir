if Code.ensure_loaded?(Ecto.ParameterizedType) do
  defmodule TypeID.Ecto do
    @moduledoc false

    @doc false
    def init(opts), do: validate_opts!(opts)

    @doc false
    def type(%{type: type}), do: type

    @doc false
    def autogenerate(params) do
      params
      |> find_prefix()
      |> TypeID.new()
    end

    @doc false
    def cast(nil, _params), do: {:ok, nil}

    def cast(tid, params) do
      if TypeID.prefix(tid) == find_prefix(params) do
        {:ok, tid}
      else
        :error
      end
    end

    @doc false
    def dump(nil, _dumper, _params), do: {:ok, nil}

    def dump(tid, _, %{type: type} = params) do
      prefix = find_prefix(params)

      case {TypeID.prefix(tid), type} do
        {^prefix, :string} -> {:ok, TypeID.to_string(tid)}
        {^prefix, :binary_id} -> {:ok, TypeID.uuid(tid)}
        _ -> :error
      end
    end

    def dump(_, _, _), do: :error

    @doc false
    def load(nil, _, _), do: {:ok, nil}

    def load(str, _, %{type: :string} = params) do
      prefix = find_prefix(params)

      with {:ok, tid} = loaded <- TypeID.from_string(str),
           true <- prefix == TypeID.prefix(tid) do
        loaded
      end
    end

    def load(<<_::128>> = uuid, _, %{type: :binary_id} = params) do
      prefix = find_prefix(params)
      TypeID.from_uuid_bytes(prefix, uuid)
    end

    def load(<<_::288>> = uuid, _, %{type: :binary_id} = params) do
      prefix = find_prefix(params)
      TypeID.from_uuid(prefix, uuid)
    rescue
      _ -> :error
    end

    def load(_, _, _), do: :error

    defp validate_opts!(opts) do
      primary_key = Keyword.get(opts, :primary_key, false)
      schema = Keyword.fetch!(opts, :schema)
      field = Keyword.fetch!(opts, :field)
      default_type = Application.get_env(:typeid_elixir, :default_type, :string)
      type = Keyword.get(opts, :type, default_type)
      prefix = Keyword.get(opts, :prefix)

      if primary_key do
        unless prefix && prefix =~ ~r/^[a-z]{0,63}$/ do
          raise ArgumentError,
                "must specify `prefix` using only lowercase letters between 0 and 63 characters long."
        end
      end

      unless type in ~w[string binary_id]a do
        raise ArgumentError, "`type` must be `:string` or `:binary_id`"
      end

      cond do
        primary_key != nil ->
          %{primary_key: primary_key, schema: schema, field: field, prefix: prefix, type: type}

        prefix != nil ->
          %{schema: schema, field: field, type: type, prefix: prefix}

        true ->
          %{schema: schema, field: field, type: type}
      end
    end

    defp find_prefix(%{prefix: prefix}) when not is_nil(prefix), do: prefix

    defp find_prefix(%{schema: schema, field: field}) do
      %{related: schema, related_key: field} = schema.__schema__(:association, field)
      {:parameterized, TypeID, %{prefix: prefix}} = schema.__schema__(:type, field)

      prefix
    end

    defp find_prefix(%{prefix: prefix}), do: prefix
  end
end
