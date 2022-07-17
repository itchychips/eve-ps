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
using Dapper;
using EveCore.Lib.Types;
using System.Data;

namespace EveCore.Lib
{
    public class EvePsRepository : IDisposable
    {
        private readonly IDbConnection _connection;
        public EvePsRepository(IDbConnection connection)
        {
            _connection = connection;
        }

        public int CreateEsiCategoryTable()
        {
            return _connection.Execute(@"
                CREATE TABLE category (
                            CategoryId INTEGER PRIMARY KEY,
                            Name STRING,
                            Published INTEGER
                        );");
        }

        public int DropEsiCategoryTable()
        {
            return _connection.Execute(@"
                DROP TABLE IF EXISTS category;");
        }

        public int DeleteEsiCategoryTable()
        {
            return _connection.Execute(@"
                DELETE FROM category
                WHERE 1=1;");
        }

        public int DeleteEsiCategory(EsiCategory category)
        {
            var sql = @"
                DELETE FROM category
                WHERE CategoryId = @CategoryId";
            sql = sql.AddWhereParameter("Name", category.Name);
            sql = sql.AddWhereParameter("Published", category.Published);

            return _connection.Execute(sql, category);
        }

        public IList<EsiCategory> GetEsiCategory(long? categoryId = null, string? name = null, bool? published = null)
        {
            var sql = @"
                SELECT categoryId, name, published
                FROM category
                WHERE 1=1";
            sql = sql.AddWhereParameter("CategoryId", categoryId);
            sql = sql.AddWhereLikeParameter("Name", name);
            sql = sql.AddWhereParameter("Published", published);

            var searchCategory = new EsiCategory
            {
                CategoryId = categoryId ?? 0,
                Name = name,
                Published = published,
            };

            var output = _connection.Query<EsiCategory>(sql, searchCategory).ToList();

            return output;
        }

        public int InsertEsiCategory(EsiCategory category)
        {
            return _connection.Execute(@"
                INSERT INTO category (
                    CategoryId, Name, Published
                ) VALUES (
                    @CategoryId,
                    @Name,
                    @Published);", category);
        }

        public int InsertOrUpdateEsiCategory(EsiCategory category)
        {
            return _connection.Execute(@"
                INSERT INTO category (
                    CategoryId, Name, Published
                ) VALUES (
                    @CategoryId,
                    @Name,
                    @Published)
                ON CONFLICT (CategoryId) DO
                UPDATE SET
                    Name = @Name,
                    Published = @Published;", category);
        }

        public int UpdateEsiCategory(EsiCategory category)
        {
            return _connection.Execute(@"
                UPDATE category
                SET
                    Name = @Name,
                    Published = @Published
                WHERE CategoryId = @CategoryId;", category);
        }

        public void Dispose()
        {
            _connection.Dispose();
            GC.SuppressFinalize(this);
        }
    }
}