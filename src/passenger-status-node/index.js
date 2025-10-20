var async = require('async')
var exec = require('child_process').exec
var parser = require('xml2json')

function convertStdoutToString (stdout, stderr, next) {
  next(null, stdout.toString('utf8'))
}

function parseXML (xmlString, next) {
  var options = {
    object: true
  }
  var obj = parser.toJson(xmlString, options)
  next(null, obj)
}

function reformat (name, obj, next) {
  obj = obj.info
  obj.name = name

  if (obj.supergroups && obj.supergroups.supergroup) {
    if (!obj.supergroups.supergroup.length) {
      obj.supergroups = [obj.supergroups.supergroup]
    } else {
      obj.supergroups = obj.supergroups.supergroup
    }
    obj.supergroups = obj.supergroups.map(function supergroupsMap (supergroup) {
      if (!supergroup) return

      if (!supergroup.group.processes.process.length) {
        supergroup.group.processes = [supergroup.group.processes.process]
      } else {
        supergroup.group.processes = supergroup.group.processes.process
      }
      supergroup.group.processes = supergroup.group.processes
        .map(function processForEach (process) {
          if (!process.sockets.socket.length) {
            process.sockets = [process.sockets.socket]
          }else{
            process.sockets = process.sockets.socket
          }
          return process
        })
      return supergroup
    })
  }
  if (!obj.supergroups || !obj.supergroups[0]) obj.supergroups = []
  next(null, obj)
}

// Calls next with names output by passenger-status
function getNames (next) {
  exec('passenger-status', function onGetNames (err, stdout, stderr) {
    var hasMultipleNames = !!err
    var output = stdout.toString('utf8')
    var result

    if (hasMultipleNames) {
      result = output.split(/^\-+$/gm)[1]

      if (result) {
        result = result
          .split('\n')
          .slice(1, 3)
          .map(function (value) {
            return value.split(/ /)[0]
          })
      }
    } else {
      result = /Instance: *([a-zA-Z0-9_]*)/g.exec(output).slice(1, 2)
    }

    next(null, result || [])
  })
}

function getInstanceMetrics (name, next) {
  async.waterfall([
    exec.bind(null, 'passenger-status --show=xml -v ' + name),
    convertStdoutToString,
    parseXML,
    reformat.bind(null, name)
  ], next)
}

function getAllMetrics (names, next) {
  if (names.length) {
    var tasks = []
    names.forEach(function getMetricsForEach (value) {
      tasks.push(getInstanceMetrics.bind(null, value))
    })

    async.parallel(tasks, next)
  } else {
    next(null, names)
  }
}

function getInstances (next) {
  async.waterfall([
    getNames,
    getAllMetrics
  ], next)
}

function searchInstances (nameSearch, instances, next) {
  if (!nameSearch) return next(null, instances)

  var results = []
  instances.forEach(function searchForEach (instance) {
    if (instance.supergroups && instance.supergroups.length) {
      instance.supergroups.forEach(function supergroupsForEach (supergroup) {
        if (supergroup &&
          supergroup.name &&
          supergroup.name.indexOf(nameSearch) > -1) results.push(instance)
      })
    } else {
      results.push(instance)
    }
  })
  next(null, results)
}

function passengerStatusNode (nameSearch, next) {
  async.waterfall([
    getInstances,
    searchInstances.bind(null, nameSearch)
  ], next)
}

module.exports = passengerStatusNode
