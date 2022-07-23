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
using System.Data;

namespace EveCore.Lib
{
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

        /// <summary>
        /// Adds a where parameter to SQL query text.  This does NOT introduce
        /// a SQL injection issue if you ensure that no user input is being
        /// used to determine the name of the parameter.  If the value passed
        /// is null, the input query text will be returned without changes.
        /// You must still pass the value as a SQL parameter into a prepared
        /// statement.
        /// </summary>
        /// <param name="queryText"></param>
        /// <param name="name"></param>
        /// <param name="value"></param>
        /// <returns>The same or appended-to query text.</returns>
        public static string AddWhereParameter(this string queryText, string name, object? value)
        {
            if (value == null)
            {
                return queryText;
            }

            queryText += $@"
                AND {name} = @{name}";

            return queryText;
        }

        /// <summary>
        /// Adds a where parameter to SQL query text for a LIKE condition.
        /// This does NOT introduce a SQL injection issue if you ensure that no
        /// user input is being used to determine the name of the parameter.
        /// If the value passed is null, the input query text will be returned
        /// without changes. You must still pass the value as a SQL parameter
        /// into a prepared statement.
        /// </summary>
        /// <param name="queryText"></param>
        /// <param name="name"></param>
        /// <param name="value"></param>
        /// <returns>The same or appended-to query text.</returns>
        public static string AddWhereLikeParameter(this string queryText, string name, string? value)
        {
            if (value == null)
            {
                return queryText;
            }

            queryText += $@"
                AND {name} LIKE @{name}";
            return queryText;
        }
    }
}