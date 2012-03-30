{spawn} = require 'child_process'

chain = (cmds) ->
  next = ->
    return unless cmds?.length
    args = cmds.shift().split(' ')
    cmd = args.shift()
    console.log {cmd, args}
    spawn(cmd, args).on 'exit', (code, signal) ->
      if code
        console.error "FAILED: #{cmd} #{args.join ' '}"
        return process.exit code
      next()
  console.log cmds
  next()

chain [
  'npm test'
  'make -C doc html'
  'git checkout gh-pages'
  'cp -R doc/.build/html/ .'
  "git commit -a -m v#{process.env.npm_package_version}"
  "git checkout master"
]
