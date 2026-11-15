import { loadPyodide } from "pyodide";
import { setupPyCall } from "./dist/index.js";

export default {
  async setup({ vm }) {
    const pyodide = await loadPyodide();
    await pyodide.loadPackage("numpy");

    setupPyCall(vm, pyodide);

    await pyodide.runPythonAsync(`
class Box:
    def __init__(self):
        self.value = 42

def echo(value):
    return value

def keyword_probe(value=None, *, offset=0):
    return (value.key if value is not None else 0) + offset

class KeywordBox:
    def __init__(self, value=None, *, offset=0):
        self.value = keyword_probe(value, offset=offset)
`);
  },
};
