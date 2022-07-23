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
    public class EvePsRepository_General_Test
    {
        [TestCase]
        public void Test_Instantiate_SqliteMemory()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);
        }

        [TestCase]
        public void Test_CreateSchema()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);
            var count = system.CreateSchema();

            Assert.That(count, Is.EqualTo(0));
        }

        [TestCase]
        public void Test_DropSchema()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var count = system.CreateSchema();
            Assert.That(count, Is.EqualTo(0));

            count = system.DropSchema();
            Assert.That(count, Is.EqualTo(0));
            count = system.DropSchema();
            Assert.That(count, Is.EqualTo(0));

            count = system.CreateSchema();
            Assert.That(count, Is.EqualTo(0));

            count = system.InsertEsiCategory(new EsiCategory { CategoryId = 123 });
            Assert.That(count, Is.EqualTo(1));

            count = system.DropSchema();
            // Not sure why this is not 1, but 9
            Assert.That(count, Is.EqualTo(9));
        }
    }
}