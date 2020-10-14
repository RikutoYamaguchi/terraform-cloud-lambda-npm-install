const moment = require('moment')

exports.handler = () => {
  console.log(moment().format('YYYY-MM-DD HH:mm:ss'))
}
