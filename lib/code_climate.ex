defmodule CodeClimate do
  @moduledoc """
  Documentation for Codeclimate.
  """

  @config_filename "/config.json"
  @cmd "mix"
  @default_opts ~w[credo --format=json]

  @category_duplication "Duplication"
  @category_clarity "Clarity"
  @category_complexity "Complexity"
  @category_bug_risk "Bug Risk"

  @issue_category %{
    "Credo.Check.Design.DuplicatedCode" => [@category_duplication],
    "Credo.Check.Readability.ModuleDoc" => [@category_clarity],
    "Credo.Check.Readability.ModuleNames" => [@category_clarity],
    "Credo.Check.Refactor.ABCSize" => [@category_complexity],
    "Credo.Check.Refactor.CyclomaticComplexity" => [@category_complexity],
    "Credo.Check.Warning.NameRedeclarationByFn" => [@category_clarity],
    "Credo.Check.Warning.OperationOnSameValues" => [@category_bug_risk],
    "Credo.Check.Warning.BoolOperationOnSameValues" => [@category_bug_risk],
    "Credo.Check.Warning.UnusedEnumOperation" => [@category_bug_risk],
    "Credo.Check.Warning.UnusedKeywordOperation" => [@category_bug_risk],
    "Credo.Check.Warning.UnusedListOperation" => [@category_bug_risk],
    "Credo.Check.Warning.UnusedStringOperation" => [@category_bug_risk],
    "Credo.Check.Warning.UnusedTupleOperation" => [@category_bug_risk],
    "Credo.Check.Warning.OperationWithConstantResult" => [@category_bug_risk]
  }

  def main([path]) do
    {:ok, config} = open_config_file(@config_filename)

    opts = @default_opts ++ build_options_from_config(config, path) ++ [path]

    {out, _exit} = System.cmd(@cmd, opts, stderr_to_stdout: false)

    print_issues(out, path)
  end

  defp print_issues(issues, path) do
    decode_json(issues)
    |> Enum.map(&to_json(&1, path))
    |> Enum.join("\0")
    |> IO.puts()
  end

  defp decode_json(issues) do
    case Jason.decode(issues) do
      {:ok, res} ->
        %{"issues" => issues} = res
        issues

      {:error, err} ->
        raise err
    end
  end

  defp to_json(issue, path) do
    %{
      "priority" => priority,
      "check" => check,
      "message" => message,
      "filename" => filename,
      "line_no" => line,
      "column" => column_start,
      "column_end" => column_end
    } = issue

    %{
      type: "issue",
      categories: categories(check),
      check_name: check,
      description: message,
      remediation_points: 50_000,
      severity: severity(priority),
      content: %{
        body: message
      },
      location: %{
        path: Path.relative_to(filename, path),
        positions: %{
          begin: %{
            line: line || 1,
            column: column_start || 1
          },
          end: %{
            line: line || 1,
            column: column_end || 1
          }
        }
      }
    }
    |> Jason.encode!()
  end

  defp categories(check) do
    @issue_category[check] || ["Style"]
  end

  defp severity(priority) do
    case priority do
      priority when priority > 20 -> "blocker"
      priority when priority in 10..19 -> "critical"
      priority when priority in 0..9 -> "major"
      priority when priority in -10..-1 -> "minor"
      priority when priority < -10 -> "info"
    end
  end

  defp open_config_file(filename) do
    with {:ok, body} <- File.read(filename), {:ok, json} <- Jason.decode(body), do: {:ok, json}
  end

  defp build_options_from_config(config, path) do
    []
    |> process_include_paths(config, path)
    |> process_strict(config)
    |> process_all(config)
    |> process_only(config)
    |> process_ignore(config)
  end

  defp process_include_paths(opts, %{"include_paths" => include_paths}, path) do
    opts ++
      Enum.map(include_paths, fn include ->
        "--files-included=#{path}/#{include}"
      end)
  end

  defp process_include_paths(opts, _, _), do: opts

  defp process_strict(opts, %{"strict" => true}), do: opts ++ ["--strict"]
  defp process_strict(opts, _), do: opts

  defp process_all(opts, %{"all" => true}), do: opts ++ ["--all"]
  defp process_all(opts, _), do: opts

  defp process_only(opts, %{"only" => only}), do: opts ++ ["--only=#{only}"]
  defp process_only(opts, _), do: opts

  defp process_ignore(opts, %{"ignore" => ignore}), do: opts ++ ["--ignore=#{ignore}"]
  defp process_ignore(opts, _), do: opts
end
