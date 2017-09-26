'use strict';

var exec = require('child_process').exec;
var path = require('path');

var READ_SCRIPT_PATH = path.join(__dirname, './awk/readInterfaces.awk');
var WRITE_SCRIPT_PATH = path.join(__dirname, './awk/changeInterface.awk');
var DEFAULT_INTERFACE = 'eth0';
var DEFAULT_INTERFACE_FILE_LOCATION = '/etc/network/interfaces';
var ADDRESS_RETURN_ORDER = ['address', 'netmask', 'gateway'];

var convertArgsForScript = function convertArgsForScript(interfacesFilePath, args) {
  var converted = [interfacesFilePath];

  // The script requires that device be specified as
  // "dev=<deviceName>" if changing the interface
  converted.push('dev=' + args.device);
  delete args.device;

  for (var key in args) {
    converted.push(key + '=' + args[key]);
  }

  return converted.join(' ');
};

var formatResult = function formatResult(textResult) {
  var rows = textResult.replace(/^(?=\n)$|^\s*|\s*$|\n\n+/gm,"").split('\n');
  var rawResult = rows[0].split(' ');
  var formattedResult = {};

  if (rawResult[0] === 'dhcp' || rawResult[0] === 'manual') {
    formattedResult.mode = rawResult[0];
  } else {
    for (var i = 0; i < rawResult.length; i++) {
      formattedResult[ADDRESS_RETURN_ORDER[i]] = rawResult[i];
    }
    if(rows.length > 1){
      for(var n = 1;n < rows.length; n++){
        var fields = rows[n].split(' ');
        formattedResult[fields[0]] = fields[1] || '';
      }
    }
  }

  return formattedResult;
};

var writeToFile = function writeToFile(filePath, content) {
  return new Promise(function (resolve, reject) {
    exec('echo "' + content + '" | sudo tee  ' + filePath + ' > /dev/null', function (error, stdout, stderr) {
      if (error) {
        reject(error);
      } else {
        resolve(stdout);
      }
    });
  });
};

var runScript = function runScript(scriptName, args) {
  return new Promise(function (resolve, reject) {
    var child = exec('awk -f ' + scriptName + ' ' + args, function (error, stdout, stderr) {
      if (error) {
        reject(error);
      }
      resolve(stdout);
    });
  });
};

var read = function read(interfacesFilePath, interfaceName) {
  interfacesFilePath = interfacesFilePath || DEFAULT_INTERFACE_FILE_LOCATION;
  interfaceName = interfaceName || DEFAULT_INTERFACE;

  return new Promise(function (resolve, reject) {
    runScript(READ_SCRIPT_PATH, [interfacesFilePath, 'device=' + interfaceName,'output=all'].join(' ')).then(function (success) {
      resolve(formatResult(success));
    }).catch(function (error) {
      reject(error);
    });
  });
};

var write = function write(interfacesFilePath, interfaceName, args) {
  interfacesFilePath = interfacesFilePath || DEFAULT_INTERFACE_FILE_LOCATION;
  interfaceName = interfaceName || DEFAULT_INTERFACE;

  return new Promise(function (resolve, reject) {
    args.device = interfaceName;
    var formattedArgs = convertArgsForScript(interfacesFilePath, args);

    runScript(WRITE_SCRIPT_PATH, formattedArgs).then(function (newText) {
      writeToFile(interfacesFilePath, newText).then(function (success) {
        resolve(args);
      }).catch(function (fileWriteError) {
        reject(fileWriteError);
      });
    }).catch(function (error) {
      console.log('Error running script: ' + error);
      reject(error);
    });
  });
};

module.exports = {
  read: read,
  write: write
};