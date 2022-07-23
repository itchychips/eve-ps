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

        public int CreateSchema()
        {
            return _connection.Execute(@"
                CREATE TABLE IF NOT EXISTS market_order (
                    OrderId INTEGER PRIMARY KEY,
                    Duration INTEGER,
                    IsBuyOrder INTEGER,
                    Issued TEXT,
                    LocationId INTEGER,
                    MinVolume INTEGER,
                    Price REAL,
                    Range INTEGER,
                    SystemId INTEGER,
                    TypeId INTEGER,
                    TypeName TEXT,
                    TypeVolume REAL,
                    VolumeRemain INTEGER,
                    VolumeTotal INTEGER) STRICT;

                CREATE TABLE IF NOT EXISTS station (
                    MaxDockableShipVolume REAL,
                    Name TEXT,
                    OfficeRentalCost REAL,
                    Owner INTEGER,
                    PositionX REAL,
                    PositionY REAL,
                    PositionZ REAL,
                    RaceId INTEGER,
                    ReprocessingEfficiency REAL,
                    ReprocessingStationsTake REAL,
                    StationId INTEGER PRIMARY KEY,
                    SystemId INTEGER,
                    TypeId INTEGER) STRICT;

                CREATE TABLE IF NOT EXISTS system (
                    ConstellationId INTEGER,
                    Name TEXT,
                    SecurityClass TEXT,
                    SecurityStatus REAL,
                    StarId INTEGER,
                    SystemId INTEGER PRIMARY KEY) STRICT;

                CREATE TABLE IF NOT EXISTS constellation (
                    ConstellationId INTEGER PRIMARY KEY,
                    Name TEXT,
                    RegionId INTEGER) STRICT;

                CREATE TABLE IF NOT EXISTS region (
                    description TEXT,
                    Name TEXT,
                    RegionId INTEGER PRIMARY KEY) STRICT;

                -- This might be in its own database instead.
                --CREATE TABLE IF NOT EXISTS cache_web (
                --    CacheWebId INTEGER PRIMARY KEY,
                --    Uri TEXT,
                --    ETag TEXT,
                --    Response TEXT,
                --    Expiry TEXT);

                CREATE TABLE IF NOT EXISTS market_group (
                    MarketGroupId INTEGER PRIMARY KEY,
                    ParentGroupId INTEGER,
                    Description TEXT,
                    Name TEXT) STRICT;

                CREATE TABLE IF NOT EXISTS category (
                    CategoryId INTEGER PRIMARY KEY,
                    Name TEXT NOT NULL,
                    Published INTEGER NOT NULL) STRICT;

                CREATE TABLE IF NOT EXISTS [group] (
                    GroupId INTEGER PRIMARY KEY,
                    CategoryId INTEGER NOT NULL,
                    Name TEXT NOT NULL,
                    Published INTEGER NOT NULL) STRICT;

                CREATE TABLE IF NOT EXISTS type (
                    TypeId INTEGER PRIMARY KEY,
                    Capacity REAL,
                    Description TEXT NOT NULL,
                    GraphicId INTEGER,
                    GroupId INTEGER NOT NULL,
                    IconId INTEGER,
                    MarketGroupId INTEGER,
                    Mass REAL,
                    Name TEXT NOT NULL,
                    PackagedVolume REAL,
                    PortionSize INTEGER,
                    Published INTEGER NOT NULL,
                    Radius REAL,
                    Volume REAL) STRICT;
            ");
        }

        public int DropSchema()
        {
            return _connection.Execute(@"
                DROP TABLE IF EXISTS type;
                DROP TABLE IF EXISTS [group];
                DROP TABLE IF EXISTS category;
                DROP TABLE IF EXISTS market_group;
                DROP TABLE IF EXISTS region;
                DROP TABLE IF EXISTS constellation;
                DROP TABLE IF EXISTS system;
                DROP TABLE IF EXISTS station;
                DROP TABLE IF EXISTS market_order;");
        }

        //public int DeleteEsiCategoryTable()
        //{
        //    return _connection.Execute(@"
        //        DELETE FROM category
        //        WHERE 1=1;");
        //}

        public int DeleteEsiCategory(long categoryId)
        {
            var sql = @"
                DELETE FROM category
                WHERE CategoryId = @CategoryId;";

            return _connection.Execute(sql, new { CategoryId = categoryId });
        }

        public IEnumerable<EsiCategory> GetEsiCategory(long? categoryId = null, string? name = null, bool? published = null)
        {
            var sql = @"
                SELECT CategoryId, Name, Published
                FROM category
                WHERE 1=1";
            sql = sql.AddWhereParameter("CategoryId", categoryId);
            sql = sql.AddWhereLikeParameter("Name", name);
            sql = sql.AddWhereParameter("Published", published);

            var searchCategory = new EsiCategory
            {
                CategoryId = categoryId ?? 0,
                Name = name ?? "",
                Published = published ?? true,
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

        public int InsertEsiGroup(EsiGroup group)
        {
            return _connection.Execute(@"
                INSERT INTO [group] (GroupId, CategoryId, Name, Published) VALUES
                    (@GroupId, @CategoryId, @Name, @Published);", group);
        }

        public IEnumerable<EsiGroup> GetEsiGroup(long? groupId = null, long? categoryId = null, string? name = null, bool? published = null)
        {
            var sql = @"
                SELECT GroupId, CategoryId, Name, Published
                FROM [group]
                WHERE 1=1";
            sql = sql.AddWhereParameter("GroupId", groupId);
            sql = sql.AddWhereParameter("CategoryId", categoryId);
            sql = sql.AddWhereLikeParameter("Name", name);
            sql = sql.AddWhereParameter("Published", published);
            var group = new EsiGroup
            {
                GroupId = groupId ?? 0,
                CategoryId = categoryId ?? 0,
                Name = name ?? "",
                Published = published ?? false,
            };
            return _connection.Query<EsiGroup>(sql, group);
        }

        public int DeleteEsiGroup(long groupId)
        {
            var sql = @"
                DELETE FROM [group]
                WHERE GroupId = @GroupId;";

            return _connection.Execute(sql, new { GroupId = groupId });
        }

        public int UpdateEsiGroup(EsiGroup group)
        {
            var sql = @"
                UPDATE [group]
                SET Name = @Name,
                    Published = @Published,
                    CategoryId = @CategoryId
                WHERE GroupId = @GroupId;";
            return _connection.Execute(sql, group);
        }

        public int InsertEsiType(EsiType type)
        {
            var sql = @"
                INSERT INTO type (
                    TypeId,
                    Capacity,
                    Description,
                    GraphicId,
                    GroupId,
                    IconId,
                    MarketGroupId,
                    Mass,
                    Name,
                    PackagedVolume,
                    PortionSize,
                    Published,
                    Radius,
                    Volume
                ) VALUES (
                    @TypeId,
                    @Capacity,
                    @Description,
                    @GraphicId,
                    @GroupId,
                    @IconId,
                    @MarketGroupId,
                    @Mass,
                    @Name,
                    @PackagedVolume,
                    @PortionSize,
                    @Published,
                    @Radius,
                    @Volume);";
            return _connection.Execute(sql, type);
        }

        public IEnumerable<EsiType> GetEsiType(long? typeId = null, long? groupId = null, long? marketGroupId = null, string? name = null)
        {
            var sql = @"
                SELECT TypeId,
                    Capacity,
                    Description,
                    GraphicId,
                    GroupId,
                    IconId,
                    MarketGroupId,
                    Mass,
                    Name,
                    PackagedVolume,
                    PortionSize,
                    Published,
                    Radius,
                    Volume
                FROM type
                WHERE 1=1";

            sql = sql.AddWhereParameter("TypeId", typeId);
            sql = sql.AddWhereParameter("GroupId", groupId);
            sql = sql.AddWhereParameter("MarketGroupId", marketGroupId);
            sql = sql.AddWhereParameter("Name", name);
            var parameters = new
            {
                TypeId = typeId,
                GroupId = groupId,
                MarketGroupId = marketGroupId,
                Name = name,
            };
            return _connection.Query<EsiType>(sql, parameters);
        }

        public int UpdateEsiType(EsiType type)
        {
            var sql = @"
                UPDATE type
                SET Capacity = @Capacity,
                    Description = @Description,
                    GraphicId = @GraphicId,
                    GroupId = @GroupId,
                    IconId = @IconId,
                    MarketGroupId = @MarketGroupId,
                    Mass = @Mass,
                    Name = @Name,
                    PackagedVolume = @PackagedVolume,
                    PortionSize = @PortionSize,
                    Published = @Published,
                    Radius = @Radius,
                    Volume = @Volume
                WHERE TypeId = @TypeId;";
            return _connection.Execute(sql, type);
        }

        public int DeleteEsiType(long typeId)
        {
            var sql = @"
                DELETE FROM type
                WHERE TypeId = @TypeId;";
            return _connection.Execute(sql, new { TypeId = typeId });
        }

        public int InsertEsiMarketGroup(EsiMarketGroup marketGroup)
        {
            var sql = @"
                INSERT INTO market_group (
                    MarketGroupId,
                    Description,
                    Name,
                    ParentGroupId
                ) VALUES (
                    @MarketGroupId,
                    @Description,
                    @Name,
                    @ParentGroupId);";

            return _connection.Execute(sql, marketGroup);
        }

        public IEnumerable<EsiMarketGroup> GetEsiMarketGroup(long? marketGroupId = null)
        {
            var sql = @"
                SELECT MarketGroupId,
                    Description,
                    Name,
                    ParentGroupId
                FROM market_group
                WHERE 1=1";
            sql = sql.AddWhereParameter("MarketGroupId", marketGroupId);

            return _connection.Query<EsiMarketGroup>(sql, new { MarketGroupId = marketGroupId });
        }

        public int UpdateEsiMarketGroup(EsiMarketGroup marketGroup)
        {
            var sql = @"
                UPDATE market_group
                SET Description = @Description,
                    Name = @Name,
                    ParentGroupId = @ParentGroupId
                WHERE MarketGroupId = @MarketGroupId;";
            return _connection.Execute(sql, marketGroup);
        }

        public int DeleteEsiMarketGroup(long marketGroupId)
        {
            var sql = @"
                DELETE FROM market_group
                WHERE MarketGroupId = @MarketGroupId;";

            return _connection.Execute(sql, new { MarketGroupId = marketGroupId });
        }

        public void Dispose()
        {
            _connection.Dispose();
            GC.SuppressFinalize(this);
        }
    }
}