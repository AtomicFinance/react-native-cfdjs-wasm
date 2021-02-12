import { NativeModules } from 'react-native';
import { Instance } from './instance';

const { CfdjsWasm } = NativeModules;

const generateId = () => {
  return (
    new Date().getTime().toString(16) +
    Math.floor(1000 * Math.random()).toString(16)
  );
};

export const initCfd = () =>
  new Promise((resolve, reject) => {
    const id = generateId();

    CfdjsWasm.initCfd(id)
      .then((keys) => {
        if (!keys) {
          reject('failed to get function names');
        } else {
          resolve(new Instance(id, JSON.parse(keys)));
        }
      })
      .catch((e) => {
        reject(e);
      });
  });
