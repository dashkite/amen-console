import chalk from "chalk"

debug = ( process.env.debug? || process.env.DEBUG? )

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
          if result.stack? && debug
            chalk.red result.stack
        else
          chalk.red "#{description} 
            (no message available - possible non-error)"
      else
        chalk.yellow description

export default print
