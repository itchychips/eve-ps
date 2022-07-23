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
    public class EvePsRepository_EsiType_Test
    {
        [TestCase]
        public void Test_Create()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var types = new List<EsiType>
            {
                new EsiType
                {
                    TypeId = 1,
                    Capacity = 1.2,
                    Description = "Type Description here",
                    GraphicId = 10,
                    GroupId = 100,
                    IconId = 1000,
                    MarketGroupId = 10000,
                    Mass = 56.7,
                    Name = "Type Name Here",
                    PackagedVolume = 2.3,
                    PortionSize = 100000,
                    Published = false,
                    Radius = 3.4,
                    Volume = 4.5,
                },
                new EsiType
                {
                    TypeId = 2,
                    Capacity = 2.2,
                    Description = "Type Description here 2",
                    GraphicId = 20,
                    GroupId = 200,
                    IconId = 2000,
                    MarketGroupId = 20000,
                    Mass = 66.7,
                    Name = "Type Name Here 2",
                    PackagedVolume = 3.3,
                    PortionSize = 200000,
                    Published = true,
                    Radius = 4.4,
                    Volume = 5.5,
                },
            };

            system.CreateSchema();
            var count = system.InsertEsiType(types[0]);
            count += system.InsertEsiType(types[1]);

            Assert.That(count, Is.EqualTo(2));
        }

        [TestCase]
        public void Test_Read()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var types = new List<EsiType>
            {
                new EsiType
                {
                    TypeId = 1,
                    Capacity = 1.2,
                    Description = "Type Description here",
                    GraphicId = 10,
                    GroupId = 100,
                    IconId = 1000,
                    MarketGroupId = 10000,
                    Mass = 56.7,
                    Name = "Type Name Here",
                    PackagedVolume = 2.3,
                    PortionSize = 100000,
                    Published = false,
                    Radius = 3.4,
                    Volume = 4.5,
                },
                new EsiType
                {
                    TypeId = 2,
                    Capacity = 2.2,
                    Description = "Type Description here 2",
                    GraphicId = 20,
                    GroupId = 200,
                    IconId = 2000,
                    MarketGroupId = 20000,
                    Mass = 66.7,
                    Name = "Type Name Here 2",
                    PackagedVolume = 3.3,
                    PortionSize = 200000,
                    Published = true,
                    Radius = 4.4,
                    Volume = 5.5,
                },
            };

            system.CreateSchema();
            system.InsertEsiType(types[0]);
            system.InsertEsiType(types[1]);

            var results = system.GetEsiType().ToList();

            Assert.That(results.Count, Is.EqualTo(2));
            Assert.That(results[0], Is.EqualTo(types[0]));
            Assert.That(results[1], Is.EqualTo(types[1]));

            results = system.GetEsiType(typeId: 2).ToList();

            Assert.That(results.Count, Is.EqualTo(1));
            Assert.That(results[0], Is.EqualTo(types[1]));
        }

        [TestCase]
        public void Test_Update()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var types = new List<EsiType>
            {
                new EsiType
                {
                    TypeId = 1,
                    Capacity = 1.2,
                    Description = "Type Description here",
                    GraphicId = 10,
                    GroupId = 100,
                    IconId = 1000,
                    MarketGroupId = 10000,
                    Mass = 56.7,
                    Name = "Type Name Here",
                    PackagedVolume = 2.3,
                    PortionSize = 100000,
                    Published = false,
                    Radius = 3.4,
                    Volume = 4.5,
                },
                new EsiType
                {
                    TypeId = 2,
                    Capacity = 2.2,
                    Description = "Type Description here 2",
                    GraphicId = 20,
                    GroupId = 200,
                    IconId = 2000,
                    MarketGroupId = 20000,
                    Mass = 66.7,
                    Name = "Type Name Here 2",
                    PackagedVolume = 3.3,
                    PortionSize = 200000,
                    Published = true,
                    Radius = 4.4,
                    Volume = 5.5,
                },
            };

            system.CreateSchema();
            system.InsertEsiType(types[0]);
            system.InsertEsiType(types[1]);

            types[0].Mass = 69.0;

            var count = system.UpdateEsiType(types[0]);
            var results = system.GetEsiType().ToList();

            Assert.That(count, Is.EqualTo(1));
            Assert.That(results[0], Is.EqualTo(types[0]));
        }

        [TestCase]
        public void Test_Delete()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var types = new List<EsiType>
            {
                new EsiType
                {
                    TypeId = 1,
                    Capacity = 1.2,
                    Description = "Type Description here",
                    GraphicId = 10,
                    GroupId = 100,
                    IconId = 1000,
                    MarketGroupId = 10000,
                    Mass = 56.7,
                    Name = "Type Name Here",
                    PackagedVolume = 2.3,
                    PortionSize = 100000,
                    Published = false,
                    Radius = 3.4,
                    Volume = 4.5,
                },
                new EsiType
                {
                    TypeId = 2,
                    Capacity = 2.2,
                    Description = "Type Description here 2",
                    GraphicId = 20,
                    GroupId = 200,
                    IconId = 2000,
                    MarketGroupId = 20000,
                    Mass = 66.7,
                    Name = "Type Name Here 2",
                    PackagedVolume = 3.3,
                    PortionSize = 200000,
                    Published = true,
                    Radius = 4.4,
                    Volume = 5.5,
                },
            };

            system.CreateSchema();
            system.InsertEsiType(types[0]);
            system.InsertEsiType(types[1]);

            var count = system.DeleteEsiType(types[0].TypeId);
            var results = system.GetEsiType().ToList();

            Assert.That(count, Is.EqualTo(1));
            Assert.That(results[0], Is.Not.EqualTo(types[0]));
        }
    }
}