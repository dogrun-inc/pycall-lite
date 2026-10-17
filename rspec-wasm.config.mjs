import { loadPyodide } from "pyodide";
import { setupPyCall } from "./dist/index.js";

export default {
  async setup({ vm }) {
    const pyodide = await loadPyodide();

    setupPyCall(vm, pyodide);

    await pyodide.runPythonAsync(`
class Box:
    def __init__(self):
        self.value = 42

def echo(value):
    return value
`);
  },
};