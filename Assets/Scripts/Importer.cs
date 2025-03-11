#if PIToolKit
using PIToolKit.Model;
using PIToolKit.Public;
using PIToolKit.Unity; 
#endif
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

/// <summary>
/// 创建者:   Harling
/// 创建时间: 2025-03-11 13:54:10
/// 备注:     由PIToolKit工具生成
/// </summary>
/// <remarks></remarks>
public class Importer : MonoBehaviour
{
#if PIToolKit
    [FileSelector(filter = "fbx")]
    public string file;
    [Button]
    public void ImportFromFbx()
    {
        if (string.IsNullOrEmpty(file)) return;
        double time = PublicUtility.ReckonTime(() =>
        {
            GameObject temp = ModelFactory.ImportFromFile(file).ToGameObject();
            Debug.Log(temp.GetComponent<MeshFilter>().sharedMesh.GetSubMesh(0).topology);
            Undo.RegisterCreatedObjectUndo(temp, "Create");
        });
        Debug.Log($"加载耗时:{time}");
    } 
#endif


    public MeshFilter fielter;
#if PIToolKit
    [Button]
#endif
    public void ChangeTopology()
    {
        Mesh mesh = new Mesh();

        mesh.SetVertices(fielter.sharedMesh.vertices);

        List<int> indexes = new List<int>();

        for (int i = 0; i < mesh.vertices.Length - 2; i++)
        {
            indexes.Add(i);
            indexes.Add(i + 1);
        }
        indexes.Add(mesh.vertices.Length - 2);
        indexes.Add(0);

        mesh.SetIndices(indexes, MeshTopology.Lines, 0);

        mesh.RecalculateBounds();


        var cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
        Undo.RegisterCreatedObjectUndo(cube, "Cube");

        cube.GetComponent<MeshFilter>().sharedMesh = mesh;
    }
}
