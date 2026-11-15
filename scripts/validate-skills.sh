#!/usr/bin/env bash
# Checks every skills/*/SKILL.md has YAML frontmatter with a `name` that
# matches its folder and a non-empty `description`.
set -euo pipefail

cd "$(dirname "$0")/.."
status=0
count=0

for dir in skills/*/; do
  skill="$(basename "$dir")"
  file="${dir}SKILL.md"
  count=$((count + 1))

  if [[ ! -f "$file" ]]; then
    echo "FAIL $skill: missing SKILL.md"; status=1; continue
  fi

  if [[ "$(head -n 1 "$file" | tr -d '\r')" != "---" ]]; then
    echo "FAIL $skill: SKILL.md must start with '---' frontmatter"; status=1; continue
  fi

  # Frontmatter = lines between the first and second '---'
  fm="$(awk 'NR==1{next} /^---\r?$/{exit} {print}' "$file" | tr -d '\r')"
  name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n 1)"
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n 1)"

  if [[ -z "$name" ]]; then
    echo "FAIL $skill: frontmatter has no 'name'"; status=1
  elif [[ "$name" != "$skill" ]]; then
    echo "FAIL $skill: name '$name' does not match folder '$skill'"; status=1
  fi

  if [[ -z "$desc" ]]; then
    echo "FAIL $skill: frontmatter has no 'description'"; status=1
  elif (( ${#desc} > 1024 )); then
    echo "FAIL $skill: description is ${#desc} chars (max 1024)"; status=1
  fi

  if ! [[ "$skill" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "FAIL $skill: folder name must be lowercase kebab-case"; status=1
  fi
done

if (( count == 0 )); then
  echo "FAIL no skills found under skills/"; exit 1
fi

if (( status == 0 )); then
  echo "OK  $count skill(s) valid"
fi
exit $status
