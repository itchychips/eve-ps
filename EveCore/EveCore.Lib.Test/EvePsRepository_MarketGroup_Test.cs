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
using NUnit.Framework;
using System.Data.SQLite;

namespace EveCore.Lib.Test
{

    [TestFixture]
    public class EvePsRepository_MarketGroup_Test
    {
        [TestCase]
        public void Test_Create()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var items = new List<EsiMarketGroup>
            {
                new EsiMarketGroup
                {
                    MarketGroupId = 1,
                    Description = "Market Group Description 1",
                    Name = "Market Group Name 1",
                    ParentGroupId = null,
                },
                new EsiMarketGroup
                {
                    MarketGroupId = 3,
                    Description = "Market Group Description 3",
                    Name = "Market Group Name 3",
                    ParentGroupId = null,
                },
                new EsiMarketGroup
                {
                    MarketGroupId = 10,
                    Description = "Market Group Description 10",
                    Name = "Market Group Name 10",
                    ParentGroupId = 1,
                },
            };

            system.CreateSchema();
            var count = system.InsertEsiMarketGroup(items[0]);
            count += system.InsertEsiMarketGroup(items[1]);
            count += system.InsertEsiMarketGroup(items[2]);

            Assert.That(count, Is.EqualTo(3));
        }

        [TestCase]
        public void Test_Read()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var items = new List<EsiMarketGroup>
            {
                new EsiMarketGroup
                {
                    MarketGroupId = 1,
                    Description = "Market Group Description 1",
                    Name = "Market Group Name 1",
                    ParentGroupId = null,
                },
                new EsiMarketGroup
                {
                    MarketGroupId = 3,
                    Description = "Market Group Description 3",
                    Name = "Market Group Name 3",
                    ParentGroupId = null,
                },
                new EsiMarketGroup
                {
                    MarketGroupId = 10,
                    Description = "Market Group Description 10",
                    Name = "Market Group Name 10",
                    ParentGroupId = 1,
                },
            };

            system.CreateSchema();
            system.InsertEsiMarketGroup(items[0]);
            system.InsertEsiMarketGroup(items[1]);
            system.InsertEsiMarketGroup(items[2]);

            var results = system.GetEsiMarketGroup().ToList();
            Assert.That(results.Count, Is.EqualTo(3));
            Assert.That(results[0], Is.EqualTo(items[0]));
            Assert.That(results[1], Is.EqualTo(items[1]));
            Assert.That(results[2], Is.EqualTo(items[2]));
        }

        [TestCase]
        public void Test_Update()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var items = new List<EsiMarketGroup>
            {
                new EsiMarketGroup
                {
                    MarketGroupId = 1,
                    Description = "Market Group Description 1",
                    Name = "Market Group Name 1",
                    ParentGroupId = null,
                },
                new EsiMarketGroup
                {
                    MarketGroupId = 3,
                    Description = "Market Group Description 3",
                    Name = "Market Group Name 3",
                    ParentGroupId = null,
                },
                new EsiMarketGroup
                {
                    MarketGroupId = 10,
                    Description = "Market Group Description 10",
                    Name = "Market Group Name 10",
                    ParentGroupId = 1,
                },
            };

            system.CreateSchema();
            system.InsertEsiMarketGroup(items[0]);
            system.InsertEsiMarketGroup(items[1]);
            system.InsertEsiMarketGroup(items[2]);

            items[0].Description = "OMG NEW DESCRIPTION";
            items[0].Name = "OMG NEW NAME";
            items[0].ParentGroupId = 42;

            var count = system.UpdateEsiMarketGroup(items[0]);
            Assert.That(count, Is.EqualTo(1));

            var results = system.GetEsiMarketGroup().ToList();
            Assert.That(results.Count, Is.EqualTo(3));
            Assert.That(results[0], Is.EqualTo(items[0]));
            Assert.That(results[1], Is.EqualTo(items[1]));
            Assert.That(results[2], Is.EqualTo(items[2]));
        }

        [TestCase]
        public void Test_Delete()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var items = new List<EsiMarketGroup>
            {
                new EsiMarketGroup
                {
                    MarketGroupId = 1,
                    Description = "Market Group Description 1",
                    Name = "Market Group Name 1",
                    ParentGroupId = null,
                },
                new EsiMarketGroup
                {
                    MarketGroupId = 3,
                    Description = "Market Group Description 3",
                    Name = "Market Group Name 3",
                    ParentGroupId = null,
                },
                new EsiMarketGroup
                {
                    MarketGroupId = 10,
                    Description = "Market Group Description 10",
                    Name = "Market Group Name 10",
                    ParentGroupId = 1,
                },
            };

            system.CreateSchema();
            system.InsertEsiMarketGroup(items[0]);
            system.InsertEsiMarketGroup(items[1]);
            system.InsertEsiMarketGroup(items[2]);

            var count = system.DeleteEsiMarketGroup(items[1].MarketGroupId);
            Assert.That(count, Is.EqualTo(1));

            var results = system.GetEsiMarketGroup().ToList();
            Assert.That(results.Count, Is.EqualTo(2));
            Assert.That(results[0], Is.EqualTo(items[0]));
            Assert.That(results[1], Is.EqualTo(items[2]));
        }
    }
}