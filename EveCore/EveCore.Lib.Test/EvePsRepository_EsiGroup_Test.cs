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
    public class EvePsRepository_EsiGroup_Test
    {
        [TestCase]
        public void Test_Create()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var group = new EsiGroup
            {
                GroupId = 1,
                CategoryId = 11,
                Name = "Fake Group",
                Published = false,
            };

            system.CreateSchema();
            var count = system.InsertEsiGroup(group);

            Assert.That(count, Is.EqualTo(1));
        }

        [TestCase]
        public void Test_Read()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var group = new EsiGroup
            {
                GroupId = 1,
                CategoryId = 11,
                Name = "Fake Group",
                Published = false,
            };

            system.CreateSchema();
            system.InsertEsiGroup(group);
            var results = system.GetEsiGroup(categoryId: 11).ToList();

            Assert.That(results.Count, Is.EqualTo(1));
            Assert.That(results[0].GroupId, Is.EqualTo(1));
            Assert.That(results[0].CategoryId, Is.EqualTo(11));
            Assert.That(results[0].Published, Is.EqualTo(false));
        }

        [TestCase]
        public void Test_Update()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var groups = new List<EsiGroup>
            {
                new EsiGroup
                {
                    GroupId = 1,
                    CategoryId = 11,
                    Name = "Fake Group",
                    Published = false,
                },
                new EsiGroup
                {
                    GroupId = 2,
                    CategoryId = 12,
                    Name = "Fake Group Two",
                    Published = true,
                }
            };

            system.CreateSchema();
            system.InsertEsiGroup(groups[0]);
            system.InsertEsiGroup(groups[1]);

            var results = system.GetEsiGroup().ToList();

            groups[0].Name = "Fake Group Renamed";
            groups[0].CategoryId = 12;
            groups[0].Published = true;

            var count = system.UpdateEsiGroup(groups[0]);
            results = system.GetEsiGroup().ToList();

            Assert.That(count, Is.EqualTo(1));
            Assert.That(results.Count, Is.EqualTo(2));
            Assert.That(results[0].Name, Is.EqualTo("Fake Group Renamed"));
            Assert.That(results[0].CategoryId, Is.EqualTo(12));
            Assert.That(results[0].Published, Is.True);
        }

        [TestCase]
        public void Test_Delete()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var groups = new List<EsiGroup>
            {
                new EsiGroup
                {
                    GroupId = 1,
                    CategoryId = 11,
                    Name = "Fake Group",
                    Published = false,
                },
                new EsiGroup
                {
                    GroupId = 2,
                    CategoryId = 12,
                    Name = "Fake Group Two",
                    Published = true,
                }
            };

            system.CreateSchema();
            var count = system.InsertEsiGroup(groups[0]);
            count += system.InsertEsiGroup(groups[1]);

            Assert.That(count, Is.EqualTo(2));

            count = system.DeleteEsiGroup(1);

            Assert.That(count, Is.EqualTo(1));
        }
    }
}