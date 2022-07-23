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
    public class EvePsRepository_EsiCategory_Test
    {
        [TestCase]
        public void Test_Create()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);
            var count = system.CreateSchema();
            Assert.That(count, Is.EqualTo(0));

            var fakeCategory = new EsiCategory
            {
                CategoryId = 123,
                Name = "Fake Category",
                Published = false,
            };
            count = system.InsertEsiCategory(fakeCategory);
            Assert.That(count, Is.EqualTo(1));
            var results = system.GetEsiCategory();

            Assert.That(results, Is.Not.Empty);
            Assert.That(results.Count, Is.EqualTo(1));

            Assert.Throws<SQLiteException>(() => system.InsertEsiCategory(fakeCategory));
        }

        [TestCase]
        public void Test_Read()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);
            var count = system.CreateSchema();
            Assert.That(count, Is.EqualTo(0));

            var results = system.GetEsiCategory();
            Assert.That(results, Is.Empty);

            var fakeCategory = new EsiCategory
            {
                CategoryId = 123,
                Name = "Fake Category",
                Published = false,
            };

            var fakeCategory2 = new EsiCategory
            {
                CategoryId = 124,
                Name = "Fake Category2",
                Published = true,
            };
            count = system.InsertEsiCategory(fakeCategory);
            count = system.InsertEsiCategory(fakeCategory2);
            var results1 = system.GetEsiCategory(categoryId: 123);
            var results2 = system.GetEsiCategory(name: "%2");
            var results3 = system.GetEsiCategory(published: false);
            Assert.That(results1.Count, Is.EqualTo(1));
            Assert.That(results2.Count, Is.EqualTo(1));
            Assert.That(results3.Count, Is.EqualTo(1));
        }

        //[TestCase]
        //public void Test_CreateOrUpdate()
        //{
        //    var connection = new SQLiteConnection("Data Source=:MEMORY:");
        //    connection.Open();

        //    using var system = new EvePsRepository(connection);
        //    var count = system.CreateSchema();
        //    Assert.That(count, Is.EqualTo(0));

        //    var fakeCategory = new EsiCategory
        //    {
        //        CategoryId = 123,
        //        Name = "Fake Category",
        //        Published = false,
        //    };
        //    count = system.InsertOrUpdateEsiCategory(fakeCategory);
        //    Assert.That(count, Is.EqualTo(1));
        //    var results = system.GetEsiCategory().ToList();

        //    Assert.That(results.Count, Is.EqualTo(1));
        //    Assert.That(results[0].Name, Is.EqualTo("Fake Category"));
        //    Assert.That(results[0].Published, Is.False);

        //    fakeCategory.Name = "Fake Category Renamed";
        //    fakeCategory.Published = true;

        //    count = system.InsertOrUpdateEsiCategory(fakeCategory);
        //    Assert.That(count, Is.EqualTo(1));
        //    results = system.GetEsiCategory().ToList();

        //    Assert.That(results.Count, Is.EqualTo(1));
        //    Assert.That(results[0].Name, Is.EqualTo("Fake Category Renamed"));
        //    Assert.That(results[0].Published, Is.True);
        //}

        [TestCase]
        public void Test_Update()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);
            system.CreateSchema();

            var fakeCategory = new EsiCategory
            {
                CategoryId = 123,
                Name = "Fake Category",
                Published = false,
            };

            var count = system.InsertEsiCategory(fakeCategory);
            Assert.That(count, Is.EqualTo(1));

            var results = system.GetEsiCategory().ToList();
            Assert.That(results.Count, Is.EqualTo(1));
            Assert.That(results[0].CategoryId, Is.EqualTo(123));
            Assert.That(results[0].Name, Is.EqualTo("Fake Category"));
            Assert.That(results[0].Published, Is.False);

            fakeCategory.Name = "Fake Category Renamed";
            fakeCategory.Published = true;

            count = system.UpdateEsiCategory(fakeCategory);
            Assert.That(count, Is.EqualTo(1));

            results = system.GetEsiCategory().ToList();
            Assert.That(results.Count, Is.EqualTo(1));
            Assert.That(results[0].CategoryId, Is.EqualTo(123));
            Assert.That(results[0].Name, Is.EqualTo("Fake Category Renamed"));
            Assert.That(results[0].Published, Is.True);

            fakeCategory.CategoryId = 321;
            count = system.UpdateEsiCategory(fakeCategory);
            Assert.That(count, Is.EqualTo(0));
        }

        [TestCase]
        public void Test_Delete()
        {
            var connection = new SQLiteConnection("Data Source=:MEMORY:");
            connection.Open();

            using var system = new EvePsRepository(connection);

            var fakeCategories = new List<EsiCategory>
            {
                new EsiCategory
                {
                    CategoryId = 123,
                    Name = "Fake Category",
                    Published = false,
                },
                new EsiCategory
                {
                    CategoryId = 124,
                    Name = "Fake Category2",
                    Published = false,
                },
            };

            system.CreateSchema();
            system.InsertEsiCategory(fakeCategories[0]);
            system.InsertEsiCategory(fakeCategories[1]);

            var count = system.DeleteEsiCategory(fakeCategories[0].CategoryId);
            var results = system.GetEsiCategory();

            Assert.That(count, Is.EqualTo(1));
            Assert.That(results.Count, Is.EqualTo(1));

            count = system.DeleteEsiCategory(fakeCategories[0].CategoryId);
            results = system.GetEsiCategory();
            Assert.That(count, Is.EqualTo(0));
            Assert.That(results.Count, Is.EqualTo(1));
        }
    }
}