const http = require('http');
const parseUrl = require('parseurl');
const send = require('send');
const puppeteer = require('puppeteer');

send.mime.define({
  'application/wasm': ['wasm']
});

const port = 8042;

const options = {
    cacheControl: false,
    root: __dirname
};

const server = http.createServer((req, res) => {
  send(req, parseUrl(req).pathname, options).pipe(res);
});

console.log(`Starting HTTP server on port ${port}.`);
server.listen(port);

const waitMessage = (page, regex, timeout) => {
    return new Promise((resolve, reject) => {
        const listener = (message) => {
            const string = message.text();
            if (string.match(regex)) {
                page.removeListener('console', listener);
                resolve();
            }
        };
        page.on('console', listener);
        setTimeout(() => {
            page.removeListener('console', listener);
            reject(new Error('Failed to receive message before timeout.'));
        }, timeout);
    });
};

(async () => {
    console.log(`Running Puppeteer.`);
    const browser = await puppeteer.launch({args: ['--no-sandbox']});
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${port}/test.html`);
    await waitMessage(page, /SWI-Prolog WebAssembly ready/, 20000);
    console.log(`WebAssembly loaded.`);
    //await browser.close();
    //server.close();
})();
