// Simple provider to store/get the socket.io instance for other modules
let ioInstance = null;

function setIO(io) {
  ioInstance = io;
}

function getIO() {
  if (!ioInstance) {
    // Not initialized yet
    // console.warn('socket.io instance not set in provider');
  }
  return ioInstance;
}

module.exports = { setIO, getIO };