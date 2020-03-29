using Microsoft.SqlServer.Server;
using System;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using System.IO;

namespace CLR
{
    public class SCM
    {
        [Microsoft.SqlServer.Server.SqlProcedure]
        public static void SaveFile(SqlString objeto, SqlString sourcePath)
        {

            using (var connection = new SqlConnection("context connection=true"))
            {
                connection.Open();
                var cmd = new SqlCommand("SELECT object_definition(object_id) FROM sys.procedures WHERE  name = @objeto", connection);
                cmd.Parameters.AddWithValue("@objeto", objeto);
                var reader = Convert.ToString(cmd.ExecuteScalar());
                SqlContext.Pipe.Send("Saving file...");
                File.WriteAllText(Path.Combine(sourcePath.Value, string.Format("{0}.sql", objeto.Value)), reader);
                SqlContext.Pipe.Send("File saved.");
            }

        }
    }
}
