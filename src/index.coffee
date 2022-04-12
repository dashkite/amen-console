import chalk from "chalk"

print = ([description, result], indent="") ->
  if Array.isArray result
    console.error indent, chalk.blue description
    for r in result
      print r, (indent + "  ")
  else
    console.error indent,
      if result?
        if result == true
          chalk.green description
        else if result.message? and result.message != ""
          chalk.red "#{description} (#{result.message})"
        else
          chalk.red description
      else
        chalk.yellow description

debug = ([description, result], indent="") ->
  if Array.isArray result
    console.error indent, chalk.blue description
    for r in result
      debug r, (indent + "  ")
  else
    console.error indent,
      if result?
        if result == true
          chalk.green description
        else if result.message? and result.message != ""
          chalk.red "#{description} (#{result.message})"
        else
          chalk.red description
      else
        chalk.yellow description

    if result?.stack?
      console.error result.stack

export default print
export { print, debug }
