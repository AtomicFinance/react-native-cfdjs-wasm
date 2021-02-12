import Foundation
import WebKit

let js: String = """
var wrappedModule = {};

function callCfd(id, fn, args) {
  wrappedModule[id][fn](...args)
    .then(function (res) {
      window.webkit.messageHandlers.resolve.postMessage(
        JSON.stringify({ id: id, data: JSON.stringify(res) })
      );
    })
    .catch(function (e) {
      window.webkit.messageHandlers.reject.postMessage(
        JSON.stringify({ id: id, data: e.toString() })
      );
    });
  return true;
}

class CfdError extends Error {
  /**
   * constructor.
   * @param {string} message error message.
   * @param {*} errorInformation error information object.
   * @param {Error} cause cause error.
   */
  constructor(message, errorInformation = undefined, cause = undefined) {
    super(
      !errorInformation ? message : message + JSON.stringify(errorInformation)
    );
    this.name = 'CfdError';
    this.errorInformation = errorInformation;
    this.cause = cause;
  }
  // eslint-disable-next-line valid-jsdoc
  /**
   * error object string.
   * @return message string.
   */
  toString() {
    return `${this.name}: ${this.message}`;
  }
  // eslint-disable-next-line valid-jsdoc
  /**
   * get error information.
   * @return InnerErrorResponse object.
   */
  getErrorInformation() {
    return this.errorInformation;
  }
  // eslint-disable-next-line valid-jsdoc
  /**
   * get error cause.
   * @return Error or undefined.
   */
  getCause() {
    return this.cause;
  }
}

async function ccallCfd(module, func, returnType, argTypes, args) {
  const UTF8Decoder =
    typeof TextDecoder !== 'undefined' ? new TextDecoder('utf8') : undefined;
  const stringToUTF8Array = function (str, heap, outIdx, maxBytesToWrite) {
    if (!(maxBytesToWrite > 0)) return 0;
    const startIdx = outIdx;
    const endIdx = outIdx + maxBytesToWrite - 1;
    for (let i = 0; i < str.length; ++i) {
      let u;
      if (str.charCodeAt) {
        u = str.charCodeAt(i);
        if (u >= 55296 && u <= 57343) {
          const u1 = str.charCodeAt(++i);
          u = (65536 + ((u & 1023) << 10)) | (u1 & 1023);
        }
      } else {
        u = str[i];
        if (u >= 55296 && u <= 57343) {
          const u1 = str[++i];
          u = (65536 + ((u & 1023) << 10)) | (u1 & 1023);
        }
      }
      if (u <= 127) {
        if (outIdx >= endIdx) break;
        heap[outIdx++] = u;
      } else if (u <= 2047) {
        if (outIdx + 1 >= endIdx) break;
        heap[outIdx++] = 192 | (u >> 6);
        heap[outIdx++] = 128 | (u & 63);
      } else if (u <= 65535) {
        if (outIdx + 2 >= endIdx) break;
        heap[outIdx++] = 224 | (u >> 12);
        heap[outIdx++] = 128 | ((u >> 6) & 63);
        heap[outIdx++] = 128 | (u & 63);
      } else {
        if (outIdx + 3 >= endIdx) break;
        heap[outIdx++] = 240 | (u >> 18);
        heap[outIdx++] = 128 | ((u >> 12) & 63);
        heap[outIdx++] = 128 | ((u >> 6) & 63);
        heap[outIdx++] = 128 | (u & 63);
      }
    }
    heap[outIdx] = 0;
    return outIdx - startIdx;
  };
  const stringToUTF8 = function (str, outPtr, maxBytesToWrite) {
    return stringToUTF8Array(str, module['HEAPU8'], outPtr, maxBytesToWrite);
  };
  const UTF8ArrayToString = function (heap, idx, maxBytesToRead) {
    const endIdx = idx + maxBytesToRead;
    let endPtr = idx;
    let str = '';
    while (heap[endPtr] && !(endPtr >= endIdx)) ++endPtr;
    if (endPtr - idx > 16 && heap.subarray && UTF8Decoder) {
      return UTF8Decoder.decode(heap.subarray(idx, endPtr));
    } else {
      while (idx < endPtr) {
        let u0 = heap[idx++];
        if (!(u0 & 128)) {
          str += String.fromCharCode(u0);
          continue;
        }
        const u1 = heap[idx++] & 63;
        if ((u0 & 224) == 192) {
          str += String.fromCharCode(((u0 & 31) << 6) | u1);
          continue;
        }
        const u2 = heap[idx++] & 63;
        if ((u0 & 240) == 224) {
          u0 = ((u0 & 15) << 12) | (u1 << 6) | u2;
        } else {
          u0 = ((u0 & 7) << 18) | (u1 << 12) | (u2 << 6) | (heap[idx++] & 63);
        }
        if (u0 < 65536) {
          str += String.fromCharCode(u0);
        } else {
          const ch = u0 - 65536;
          str += String.fromCharCode(55296 | (ch >> 10), 56320 | (ch & 1023));
        }
      }
    }
    return str;
  };
  const UTF8ToString = function (ptr, maxBytesToRead) {
    return ptr ? UTF8ArrayToString(module['HEAPU8'], ptr, maxBytesToRead) : '';
  };
  const writeArrayToMemory = function (array, buffer) {
    module['HEAPU8'].set(array, buffer);
  };
  const toC = {
    string: function (str) {
      let ret = 0;
      if (str !== null && str !== undefined && str !== 0) {
        const len = (str.length << 2) + 1;
        ret = module['stackAlloc'](len);
        stringToUTF8(str, ret, len);
      }
      return ret;
    },
    array: function (arr) {
      const ret = module['stackAlloc'](arr.length);
      writeArrayToMemory(arr, ret);
      return ret;
    },
  };

  const convertReturnValue = function (ret) {
    if (returnType === 'string') {
      const result = UTF8ToString(ret);
      module['_cfdjsFreeString'](ret);
      return result;
    }
    if (returnType === 'boolean') return Boolean(ret);
    return ret;
  };
  // const func = getCFunc(ident);
  const cArgs = [];
  let stack = 0;
  if (args) {
    for (let i = 0; i < args.length; i++) {
      const converter = toC[argTypes[i]];
      if (converter) {
        if (stack === 0) stack = module['stackSave']();
        cArgs[i] = converter(args[i]);
      } else {
        cArgs[i] = args[i];
      }
    }
  }

  // eslint-disable-next-line prefer-spread
  let ret = func.apply(null, cArgs);
  ret = convertReturnValue(ret);
  if (stack !== 0) module['stackRestore'](stack);
  return ret;
}

async function callJsonApi(wasmModule, reqName, arg, hasThrowExcept = true) {
  let retObj;
  try {
    // stringify all arguments
    let argStr = '';
    if (arg) {
      argStr = JSON.stringify(arg, (key, value) =>
        typeof value === 'bigint' ? value.toString() : value
      );
    }

    const retJson = await ccallCfd(
      wasmModule,
      wasmModule['_cfdjsJsonApi'],
      'string',
      ['string', 'string'],
      [reqName, argStr]
    );
    retObj = JSON.parse(retJson);
  } catch (err) {
    console.log(err);
    throw new CfdError(
      'ERROR: Invalid function call:' + ` func=[${reqName}], arg=[${arg}] ${err}`,
      undefined,
      err
    );
  }

  if (hasThrowExcept && retObj.hasOwnProperty('error')) {
    throw new CfdError('', retObj.error);
  }
  return retObj;
}

async function fetchImport(url, id) {
  const res = await fetch(url);
  const source = await res.text();

  let exports = {};
  window.__dirname = '';

  const module = { exports };
  eval(source);
  return module.exports;
}

async function initCfd(id) {
  let cfdjsWasm;

  try {
    cfdjsWasm = callInit(wasmBinary);
  } catch (e) {
    window.webkit.messageHandlers.reject.postMessage(
      JSON.stringify({ id: id, data: e.toString() })
    );
    return;
  }
  
  wrappedModule[id] = {}

  cfdjsWasm['onRuntimeInitialized'] = async () => {
    const funcNameResult = await ccallCfd(
      cfdjsWasm,
      cfdjsWasm._cfdjsGetJsonApiNames,
      'string',
      [],
      []
    );
    if (funcNameResult.indexOf('Error:') >= 0) {
      throw new CfdError(
        `cfdjsGetJsonApiNames internal error. ${funcNameResult}`
      );
    }
    const funcList = funcNameResult.split(',');

    // register function list
    funcList.forEach((requestName) => {
      const hook = async function (...args) {
        if (args.length > 1) {
          throw new CfdError(
            'ERROR: Invalid argument passed:' +
              `func=[${requestName}], args=[${args}]`
          );
        }
        let arg = '';
        if (typeof args === 'undefined') {
          arg = '';
        } else if (typeof args === 'string') {
          arg = args;
        } else if (args) {
          arg = args[0];
        }
        return await callJsonApi(cfdjsWasm, requestName, arg);
      };

      Object.defineProperty(wrappedModule[id], requestName, {
        value: hook,
        enumerable: true,
      });
    });

    window.webkit.messageHandlers.resolve.postMessage(
      JSON.stringify({
        id: id,
        data: JSON.stringify(Object.keys(wrappedModule[id])),
      })
    );
  };
}
"""

struct Promise {
    let resolve: RCTPromiseResolveBlock
    let reject: RCTPromiseRejectBlock
}

struct JsResult: Codable {
    let id: String
    let data: String
}

@objc(CfdjsWasm)
class CfdjsWasm: NSObject, WKScriptMessageHandler {
    
    var webView: WKWebView!
    var asyncPool: Dictionary<String, Promise> = [:]
    
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    override init() {
        super.init()
        let webCfg: WKWebViewConfiguration = WKWebViewConfiguration()
        
        let userController: WKUserContentController = WKUserContentController()
        userController.add(self, name: "resolve")
        userController.add(self, name: "reject")
        
        let frameworkBundle = Bundle(for: CfdjsWasm.self)
        let bundleURL = frameworkBundle.resourceURL?.appendingPathComponent("CFDJS_WASM.bundle")
        let resourceBundle = Bundle(url: bundleURL!)!

        let initFilePath = resourceBundle.url(forResource: "wasm_init", withExtension: "js")
        let initCode = try? String(contentsOf: initFilePath!, encoding: .utf8)

        let wasmFilePath = resourceBundle.url(forResource: "cfdjs_wasm", withExtension: "wasm")
        var bytes = [UInt8]()

        let wasmData = NSData.init(contentsOf: wasmFilePath!)!
        var buffer = [UInt8](repeating: UInt8(0), count: wasmData.length)
        wasmData.getBytes(&buffer, length: wasmData.length)
        bytes = buffer

        let data = try? JSONSerialization.data(withJSONObject: bytes, options: [])
        let bytesArrayString = String(data: data!, encoding: String.Encoding.utf8)

        let bufferInitCode = "const wasmBinary = Uint8Array.from(\(bytesArrayString ?? "[]"));"

        webCfg.userContentController = userController
        
        webView = WKWebView(frame: .zero, configuration: webCfg)
        
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(bufferInitCode + initCode! + js) { (value, error) in
                // NOP
            }
        }
    }

    @objc
    func initCfd(_ modId: NSString, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
        asyncPool.updateValue(Promise(resolve: resolve, reject: reject), forKey: modId as String)
        
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript("""
            initCfd("\(modId)");[];
            """) { (value, error) in
                if error != nil {
                    self.asyncPool.removeValue(forKey: modId as String)
                    reject("error", "\(error)", nil)
                }
            }
        }
    }
  
    @objc
    func callCfd(_ modId: NSString, funcName name: NSString, arguments args: NSString, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
        asyncPool.updateValue(Promise(resolve: resolve, reject: reject), forKey: modId as String)
        
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript("""
            callCfd("\(modId)", "\(name)", \(args));
            """) { (value, error) in
                if error != nil {
                    self.asyncPool.removeValue(forKey: modId as String)
                    reject("error", "\(error)", nil)
                }
            }
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "resolve" {
            let json = try! JSONDecoder().decode(JsResult.self, from: (message.body as! String).data(using: .utf8)!)
            guard let promise = asyncPool[json.id] else {
                return
            }
            asyncPool.removeValue(forKey: json.id)
            promise.resolve(json.data)
        } else if message.name == "reject" {
            let json = try! JSONDecoder().decode(JsResult.self, from: (message.body as! String).data(using: .utf8)!)
            guard let promise = asyncPool[json.id] else {
                return
            }
            asyncPool.removeValue(forKey: json.id)
            promise.reject("error", json.data, nil)
        }
    }
}
