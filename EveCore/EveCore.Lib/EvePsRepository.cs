﻿using EveCore.Lib.Types;
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
                    Name = (string?)reader[1],
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

    public static class DbCommandExtension
    {
        public static void AddWhereParameter(this IDbCommand command, string name, object? value)
        {
            if (value == null)
            {
                return;
            }
            command.CommandText += $@"
                AND {name} = @{name}";
            command.AddParameter(name, value);
        }

        public static void AddWhereParameterLike(this IDbCommand command, string name, string? value)
        {
            if (value == null)
            {
                return;
            }
            command.CommandText += $@"
                AND {name} LIKE @{name}";
            command.AddParameter(name, value);
        }

        public static void AddParameter(this IDbCommand command, string name, object? value)
        {
            var parameter = command.CreateParameter();
            parameter.ParameterName = name;
            parameter.Value = value;
            command.Parameters.Add(parameter);
        }
    }
}