#!/usr/bin/env node

var passengerStatus = require('../index.js')
var options = require('minimist')(process.argv.slice(2))
var args = options._
delete options._
var nameSearch = args[0]

passengerStatus(nameSearch, function onPassengerStatus (err, output) {
  if (err) throw err
  console.log(JSON.stringify(output, null, 2))
})
