import { NativeModules } from 'react-native';
const { CfdjsWasm } = NativeModules;

export class Instance {
  constructor(id, keys) {
    const fns = keys.reduce((acc, k) => {
      acc[k] = (...args) =>
        CfdjsWasm.callCfd(id, k, JSON.stringify(args)).then((res) =>
          JSON.parse(res)
        );
      return acc;
    }, {});

    Object.assign(this, fns);
  }
}
