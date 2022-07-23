// This file is part of Eve-PS.
//
// Eve-PS is free software: you can redistribute it and/or modify it under the
// terms of the GNU Affero Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// Eve-PS is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU Affero Public License for more details.
//
// You should have received a copy of the GNU Affero Public License along with
// Eve-PS. If not, see <https://www.gnu.org/licenses/>.
using EveCore.Lib.Types;
using System.Data;

namespace EveCore.Lib
{
    public class EvePsRepository2 : IDisposable
    {
        private readonly IDbConnection _connection;
        public EvePsRepository2(IDbConnection connection)
        {
            _connection = connection;
        }

        public int CreateEsiCategoryTable()
        {
            var command = _connection.CreateCommand();
            command.CommandText = @"
                CREATE TABLE category (
                            CategoryId INTEGER PRIMARY KEY,
                            Name STRING,
                            Published INTEGER
                        );";
            return command.ExecuteNonQuery();
        }

        public int DropEsiCategoryTable()
        {
            var command = _connection.CreateCommand();
            command.CommandText = @"
                DROP TABLE IF EXISTS category;";
            return command.ExecuteNonQuery();
        }

        public int DeleteEsiCategoryTable()
        {
            var command = _connection.CreateCommand();
            command.CommandText = @"
                DELETE FROM category
                WHERE 1=1;";
            return command.ExecuteNonQuery();
        }

        public int DeleteEsiCategory(EsiCategory category)
        {
            var command = _connection.CreateCommand();
            command.CommandText = @"
                DELETE FROM category
                WHERE CategoryId = @CategoryId";
            command.AddParameter("CategoryId", category.CategoryId);
            command.AddWhereParameterLike("Name", category.Name);
            command.AddWhereParameter("Published", category.Published);
            return command.ExecuteNonQuery();
        }

        public IList<EsiCategory> GetEsiCategory(long? categoryId = null, string? name = null, bool? published = null)
        {
            using var command = _connection.CreateCommand();
            command.CommandText = @"
                SELECT categoryId, name, published
                FROM category
                WHERE 1=1";

            if (categoryId != null)
            {
                command.CommandText += @"
                    AND CategoryId = @CategoryId";
                var parameter = command.CreateParameter();
                parameter.ParameterName = "CategoryId";
                parameter.Value = categoryId;
                command.Parameters.Add(parameter);
            }

            if (name != null)
            {
                command.CommandText += @"
                    AND Name LIKE @Name";
                var parameter = command.CreateParameter();
                parameter.ParameterName = "Name";
                parameter.Value = name;
                command.Parameters.Add(parameter);
            }

            if (published != null)
            {
                command.CommandText += @"
                    AND Published = @Published";
                var parameter = command.CreateParameter();
                parameter.ParameterName = "Published";
                parameter.Value = published;
                command.Parameters.Add(parameter);
            }

            var output = new List<EsiCategory>();

            var reader = command.ExecuteReader();
            while (reader.Read())
            {
                var publishedLong = (long?)reader[2];
                var publishedBool = publishedLong.HasValue && publishedLong > 0;
                var item = new EsiCategory
                {
                    CategoryId = (long)reader[0],
                    Name = (string)reader[1],
                    Published = publishedBool,
                };
                output.Add(item);
            }
            return output;
        }

        public int InsertEsiCategory(EsiCategory category)
        {
            using var command = _connection.CreateCommand();
            command.CommandText = @"
                INSERT INTO category (
                    CategoryId, Name, Published
                ) VALUES (
                    @CategoryId,
                    @Name,
                    @Published);";
            command.AddParameter("CategoryId", category.CategoryId);
            command.AddParameter("Name", category.Name);
            command.AddParameter("Published", category.Published);
            return command.ExecuteNonQuery();
        }

        public int InsertOrUpdateEsiCategory(EsiCategory category)
        {
            using var command = _connection.CreateCommand();
            command.CommandText = @"
                INSERT INTO category (
                    CategoryId, Name, Published
                ) VALUES (
                    @CategoryId,
                    @Name,
                    @Published)
                ON CONFLICT (CategoryId) DO
                UPDATE SET
                    Name = @Name,
                    Published = @Published;";
            command.AddParameter("CategoryId", category.CategoryId);
            command.AddParameter("Name", category.Name);
            command.AddParameter("Published", category.Published);
            return command.ExecuteNonQuery();
        }

        public int UpdateEsiCategory(EsiCategory category)
        {
            using var command = _connection.CreateCommand();
            command.CommandText = @"
                UPDATE category
                SET
                    Name = @Name,
                    Published = @Published
                WHERE CategoryId = @CategoryId;";
            command.AddParameter("CategoryId", category.CategoryId);
            command.AddParameter("Name", category.Name);
            command.AddParameter("Published", category.Published);
            return command.ExecuteNonQuery();
        }

        public void Dispose()
        {
            _connection.Dispose();
            GC.SuppressFinalize(this);
        }
    }
}