const escpos = require('escpos');
escpos.USB = require('escpos-usb');
const logger = require('./logger');

// ---- Job Queue ----
const printQueue = [];
let isProcessingQueue = false;

function enqueuePrintJob(jobFn, { maxRetries = 2 } = {}) {
  return new Promise((resolve, reject) => {
    printQueue.push({ jobFn, maxRetries, attempts: 0, resolve, reject });
    processPrintQueue();
  });
}

async function processPrintQueue() {
  if (isProcessingQueue) return;
  if (!printQueue.length) return;

  isProcessingQueue = true;

  while (printQueue.length) {
    const job = printQueue.shift();
    const { jobFn } = job;

    try {
      await Promise.resolve(jobFn());
      job.resolve();
    } catch (err) {
      logger.error(`Error executing print job: ${err.message}`);

      if (job.attempts < job.maxRetries) {
        job.attempts += 1;
        logger.warn(`Retrying print job (attempt ${job.attempts}/${job.maxRetries})`);
        printQueue.unshift(job);
      } else {
        job.reject(err);
      }
    }
  }

  isProcessingQueue = false;
}

// ---- Printer Connection ----
function withPrinter(callback) {
  return new Promise((resolve, reject) => {
    try {
      // In production, you might want to auto-detect or config the VID/PID
      const usb = new escpos.USB(); 
      // Check if device found
      // escpos-usb throws if no device, but let's handle it carefully
      
      const p = new escpos.Printer(usb, { encoding: 'CP858' });

      usb.open(error => {
        if (error) {
          logger.error('Error opening printer device:', error);
          return reject(new Error('Cannot open printer'));
        }

        Promise.resolve(callback(p))
          .then(() => {
            try {
              p.close(() => resolve());
            } catch (closeErr) {
              logger.error('Error closing printer:', closeErr);
              resolve();
            }
          })
          .catch(err => {
            try {
              p.close(() => reject(err));
            } catch (closeErr) {
              logger.error('Error closing printer after failure:', closeErr);
              reject(err);
            }
          });
      });
    } catch (err) {
      logger.error('Unexpected error in printer management:', err);
      reject(err);
    }
  });
}

module.exports = {
  enqueuePrintJob,
  withPrinter
};
