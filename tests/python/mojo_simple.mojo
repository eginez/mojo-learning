from python import PythonObject
from python.bindings import PythonModuleBuilder
from os import abort

@export
fn PyInit_mojo_simple() raises -> PythonObject:
    try:
        var mb = PythonModuleBuilder("mojo_simple")
        mb.def_function[simplefn]("simplefn")
        return mb.finalize()
    except e:
        return abort[PythonObject]("error creating Mojo module")

fn simplefn(py_obj: PythonObject) raises -> PythonObject:
    return 43
