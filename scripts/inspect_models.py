#!/usr/bin/env python3
"""Dump input/output names, dtypes, shapes, opset and metadata of every .onnx in a folder,
and run one smoke inference with zero inputs. Usage: inspect_models.py <models_dir> <out.json>"""
import json, sys, time, glob, os
import numpy as np
import onnx
import onnxruntime as ort

def dims(vi):
    out = []
    for d in vi.type.tensor_type.shape.dim:
        out.append(d.dim_value if d.HasField("dim_value") else (d.dim_param or "?"))
    return out

def main(folder, out_path):
    report = {"onnx": onnx.__version__, "onnxruntime": ort.__version__, "models": {}}
    for path in sorted(glob.glob(os.path.join(folder, "*.onnx"))):
        name = os.path.basename(path)
        entry = {"sizeBytes": os.path.getsize(path)}
        try:
            m = onnx.load(path, load_external_data=False)
            entry["opset"] = [o.version for o in m.opset_import]
            entry["inputs"] = [{"name": i.name, "dtype": onnx.TensorProto.DataType.Name(i.type.tensor_type.elem_type), "shape": dims(i)} for i in m.graph.input if i.name not in {x.name for x in m.graph.initializer}]
            entry["outputs"] = [{"name": o.name, "dtype": onnx.TensorProto.DataType.Name(o.type.tensor_type.elem_type), "shape": dims(o)} for o in m.graph.output]
            entry["metadata"] = {p.key: p.value[:2000] for p in m.metadata_props}
            entry["doc_string"] = (m.doc_string or "")[:2000]
        except Exception as e:
            entry["inspectError"] = repr(e)
        try:
            so = ort.SessionOptions()
            so.intra_op_num_threads = 2
            sess = ort.InferenceSession(path, so, providers=["CPUExecutionProvider"])
            feeds = {}
            for i in sess.get_inputs():
                shape = [d if isinstance(d, int) and d > 0 else 1 for d in i.shape]
                dt = np.float16 if "float16" in i.type else np.float32
                feeds[i.name] = np.zeros(shape, dtype=dt)
            t = time.time()
            outs = sess.run(None, feeds)
            entry["smokeTest"] = {"ok": True, "seconds_on_github_runner_cpu": round(time.time() - t, 3), "outputShapes": [list(o.shape) for o in outs]}
        except Exception as e:
            entry["smokeTest"] = {"ok": False, "error": repr(e)[:500]}
        report["models"][name] = entry
        print(name, json.dumps(entry, indent=1)[:1500])
    with open(out_path, "w") as f:
        json.dump(report, f, indent=2)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
