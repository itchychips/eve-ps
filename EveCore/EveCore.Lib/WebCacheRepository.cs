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
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EveCore.Lib
{
    public class WebCacheRepository
    {
        private readonly IDbConnection _connection;

        public WebCacheRepository(IDbConnection connection)
        {
            _connection = connection;
        }

        public int CreateSchema()
        {
            return _connection.Execute(@"
                CREATE TABLE IF NOT EXISTS cache_entry (
                            Uri TEXT PRIMARY KEY,
                            ETag TEXT,
                            Response TEXT,
                            Expiry TEXT);");
        }

        public int InsertCacheEntry(CacheEntry entry)
        {
            throw new NotImplementedException();
        }
    }
}
